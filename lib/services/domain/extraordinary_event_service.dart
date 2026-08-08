import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/schedule_math.dart' as schedule_math;

final _log = getLogger('ExtraordinaryEventService');

class ExtraordinaryEventStats {
  final int entryCount;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final double totalAmount;
  final double totalAllocated; // sum of |entry.amount| for this event
  final double remaining; // totalAmount − totalAllocated (>=0 expected)
  final double totalReimbursed; // spread+buffer only

  const ExtraordinaryEventStats({
    required this.entryCount,
    this.firstDate,
    this.lastDate,
    required this.totalAmount,
    required this.totalAllocated,
    required this.remaining,
    this.totalReimbursed = 0,
  });
}

/// Unified service for "extraordinary events" — direction (inflow|outflow) ×
/// treatment (instant|spread). Replaces both CapexService and
/// IncomeAdjustmentService behind a single API.
///
/// Entry amount sign convention (stored in DB, summed as-is by chart math):
///   outflow/spread    scheduled entry: amount = −stepAmount (reduces saving)
///   inflow/manual     entry:           amount = +userAmount (restores saving)
///   reimbursement     entry (any):     amount = −|reimb|    (reduces saving)
///   outflow/instant   manual entry:    amount = −userAmount (reduces saving)
///   inflow/spread     scheduled entry: amount = +stepAmount (increases saving)
class ExtraordinaryEventService {
  final AppDatabase _db;

  ExtraordinaryEventService(this._db);

  // ── Event CRUD ──

  SimpleSelectStatement<$ExtraordinaryEventsTable, ExtraordinaryEvent> _activeEvents({DateTime? through}) {
    final query = _db.select(_db.extraordinaryEvents)..where((e) => e.isActive.equals(true));
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((e) => e.eventDate.isSmallerThanValue(endExclusive));
    }
    query.orderBy([(e) => OrderingTerm.desc(e.eventDate)]);
    return query;
  }

  Stream<List<ExtraordinaryEvent>> watchAll({DateTime? through}) => _activeEvents(through: through).watch();

  /// Tables that together define an adjustment's ledger-visible state.
  Set<TableInfo<Table, dynamic>> get _adjustmentTables => {
    _db.extraordinaryEvents,
    _db.extraordinaryEventEntries,
    _db.bufferTransactions,
  };

  /// Emits once on subscribe, then on every write to the events, entries, or
  /// buffer-transactions tables.
  ///
  /// Consumers that need events AND their entries (the All-Accounts ledger,
  /// the stats map) cannot key off `watchAll()`: that stream is a select over
  /// `extraordinary_events` only, so writing an *entry* — which is exactly
  /// what "mark as adjustment" does — never re-emits. The badge and the
  /// totals exclusion then stayed stale for the whole session and only
  /// appeared after a restart.
  ///
  /// Note `readsFrom` is only honoured by `.watch()`; declaring it on a
  /// one-shot `.get()` is inert. Hence this dedicated trigger, driven by a
  /// `.watch()`, rather than a `readsFrom` bolted onto the inner loads.
  ///
  /// `customSelect(...).watch()` is used in preference to
  /// `db.tableUpdates(...)` because the latter does not emit on subscribe,
  /// which would leave the first frame with no data.
  Stream<void> watchAdjustmentRevision() => _db.customSelect('SELECT 1', readsFrom: _adjustmentTables).watch();

  Future<List<ExtraordinaryEvent>> getAll({DateTime? through}) => _activeEvents(through: through).get();

  Future<ExtraordinaryEvent> getById(int id) {
    return (_db.select(_db.extraordinaryEvents)..where((e) => e.id.equals(id))).getSingle();
  }

  Stream<ExtraordinaryEvent> watchById(int id) {
    return (_db.select(_db.extraordinaryEvents)..where((e) => e.id.equals(id))).watchSingle();
  }

  Future<int> create({
    required String name,
    required EventDirection direction,
    required EventTreatment treatment,
    required double totalAmount,
    required String currency,
    required DateTime eventDate,
    int? transactionId,
    // Spread-only:
    StepFrequency? stepFrequency,
    DateTime? spreadStart,
    DateTime? spreadEnd,
    String? notes,
    bool isEphemeral = false,
  }) async {
    if (treatment == EventTreatment.spread) {
      if (stepFrequency == null || spreadStart == null || spreadEnd == null) {
        throw ArgumentError('spread treatment requires stepFrequency, spreadStart, spreadEnd');
      }
    }
    if (isEphemeral && (direction != EventDirection.inflow || treatment != EventTreatment.instant)) {
      throw ArgumentError(
        'isEphemeral is only valid for inflow/instant events',
      );
    }
    _log.info(
      'create: name=$name, $direction/$treatment, amount=$totalAmount'
      '${isEphemeral ? ', ephemeral' : ''}',
    );
    final id = await _db
        .into(_db.extraordinaryEvents)
        .insert(
          ExtraordinaryEventsCompanion.insert(
            name: name,
            direction: direction,
            treatment: treatment,
            totalAmount: totalAmount,
            currency: Value(currency),
            eventDate: eventDate,
            transactionId: Value(transactionId),
            stepFrequency: Value(stepFrequency),
            spreadStart: Value(spreadStart),
            spreadEnd: Value(spreadEnd),
            notes: Value(notes),
            isEphemeral: Value(isEphemeral),
          ),
        );
    if (treatment == EventTreatment.spread) {
      await generateScheduledEntries(id);
    }
    return id;
  }

  Future<bool> update(int id, ExtraordinaryEventsCompanion companion) async {
    _log.info('update: id=$id');
    final rows = await (_db.update(
      _db.extraordinaryEvents,
    )..where((e) => e.id.equals(id))).write(companion.copyWith(updatedAt: Value(DateTime.now())));
    if (rows > 0) {
      final event = await getById(id);
      if (event.treatment == EventTreatment.spread) {
        await generateScheduledEntries(id);
      } else {
        // Treatment changed away from spread — drop any leftover scheduled
        // entries so they don't show up as ghost rows on the event timeline.
        await (_db.delete(
          _db.extraordinaryEventEntries,
        )..where((e) => e.eventId.equals(id) & e.entryKind.equalsValue(EventEntryKind.scheduled))).go();
      }
    }
    return rows > 0;
  }

  Future<int> delete(int id) async {
    _log.warning('delete: event id=$id');
    final event = await getById(id);
    if (event.bufferId != null) {
      await (_db.delete(_db.bufferTransactions)..where((t) => t.bufferId.equals(event.bufferId!))).go();
      await (_db.delete(_db.buffers)..where((b) => b.id.equals(event.bufferId!))).go();
    }
    await (_db.delete(_db.extraordinaryEventEntries)..where((e) => e.eventId.equals(id))).go();
    return (_db.delete(_db.extraordinaryEvents)..where((e) => e.id.equals(id))).go();
  }

  Future<int> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return 0;
    _log.warning('deleteMany: ${ids.length} events');
    return _db.transaction(() async {
      var total = 0;
      for (final id in ids) {
        total += await delete(id);
      }
      return total;
    });
  }

  // ── Scheduled-entry generation (spread treatment only) ──
  // Regenerates entries to reflect (totalAmount − reimbursements) spread across steps.
  // Sign: outflow → negative entry amounts, inflow → positive.

  Future<void> generateScheduledEntries(int eventId) async {
    final event = await getById(eventId);
    if (event.treatment != EventTreatment.spread) {
      _log.warning('generateScheduledEntries skipped: event $eventId is instant');
      return;
    }
    if (event.spreadStart == null || event.spreadEnd == null || event.stepFrequency == null) {
      _log.warning('generateScheduledEntries skipped: event $eventId missing spread config');
      return;
    }

    final dates = schedule_math.computeStepDates(
      event.spreadStart!,
      event.spreadEnd!,
      event.stepFrequency!,
    );
    if (dates.isEmpty) return;

    final reimbursed = await _totalReimbursed(event);
    final amountToSpread = event.totalAmount - reimbursed;
    final stepAmount = amountToSpread / dates.length;
    // Sign flip: outflow entries reduce saving (negative); inflow entries add (positive).
    final signedStep = event.direction == EventDirection.outflow ? -stepAmount : stepAmount;
    _log.info(
      'generateScheduledEntries: event=$eventId, ${dates.length} steps, '
      'signedStep=$signedStep',
    );

    await _db.transaction(() async {
      await (_db.delete(
        _db.extraordinaryEventEntries,
      )..where((e) => e.eventId.equals(eventId) & e.entryKind.equalsValue(EventEntryKind.scheduled))).go();

      var cumulative = 0.0;
      for (final date in dates) {
        cumulative += stepAmount;
        final remaining = amountToSpread - cumulative;
        await _db
            .into(_db.extraordinaryEventEntries)
            .insert(
              ExtraordinaryEventEntriesCompanion.insert(
                eventId: eventId,
                date: date,
                amount: signedStep,
                entryKind: EventEntryKind.scheduled,
                cumulative: Value(cumulative),
                remaining: Value(remaining.abs() < 0.01 ? 0 : remaining),
              ),
            );
      }
    });
  }

  Future<double> _totalReimbursed(ExtraordinaryEvent event) async {
    if (event.bufferId == null) return 0;
    // Net reimbursement: a negative entry is a refund/clawback and must
    // *reduce* the total, not add to it (which is what SUM(ABS) does).
    // ABS-after-SUM keeps the magnitude positive without double-counting.
    final result = await _db
        .customSelect(
          'SELECT COALESCE(ABS(SUM(amount)), 0.0) AS total '
          'FROM buffer_transactions '
          'WHERE buffer_id = ? AND is_reimbursement = 1',
          variables: [Variable.withInt(event.bufferId!)],
          readsFrom: {_db.bufferTransactions},
        )
        .getSingle();
    return result.read<double>('total');
  }

  // ── Manual entry CRUD (instant treatment primarily; also available for spread) ──
  // The user-supplied [amount] is positive; we sign it based on event direction.

  /// How many `manual` entries this event already has on the same day for the
  /// same magnitude. Compared at cent precision and day granularity, so a
  /// time-of-day difference or float noise never hides a duplicate.
  /// Description is deliberately excluded — the user may retype it.
  ///
  /// Reported rather than enforced: two identical same-day drawdowns ARE
  /// legitimate (`resolveAdjustments` consumes each transaction at most once,
  /// so two identical entries correctly match two identical transactions).
  /// Callers use this to ask for confirmation, never to hard-block.
  Future<int> countIdenticalManualEntries({
    required int eventId,
    required DateTime date,
    required double amount,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEndExclusive = dayStart.add(const Duration(days: 1));
    final cents = (amount.abs() * 100).round();
    final result = await _db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM extraordinary_event_entries '
          'WHERE event_id = ? AND entry_kind = ? '
          'AND date >= ? AND date < ? '
          'AND CAST(ROUND(ABS(amount) * 100) AS INTEGER) = ?',
          variables: [
            Variable.withInt(eventId),
            Variable.withString(EventEntryKind.manual.name),
            Variable.withInt(dayStart.millisecondsSinceEpoch ~/ 1000),
            Variable.withInt(dayEndExclusive.millisecondsSinceEpoch ~/ 1000),
            Variable.withInt(cents),
          ],
          readsFrom: {_db.extraordinaryEventEntries},
        )
        .getSingle();
    return result.read<int>('cnt');
  }

  Future<int> addManualEntry({
    required int eventId,
    required DateTime date,
    required double amount,
    String description = '',
  }) async {
    final event = await getById(eventId);
    // Sign rule: inflow/manual restores saving (positive).
    //            outflow/manual reduces saving (negative).
    final signed = event.direction == EventDirection.inflow ? amount.abs() : -amount.abs();
    return _db
        .into(_db.extraordinaryEventEntries)
        .insert(
          ExtraordinaryEventEntriesCompanion.insert(
            eventId: eventId,
            date: date,
            amount: signed,
            entryKind: EventEntryKind.manual,
            description: Value(description),
          ),
        );
  }

  Future<void> deleteEntry(int entryId) async {
    await (_db.delete(_db.extraordinaryEventEntries)..where((e) => e.id.equals(entryId))).go();
  }

  // ── Entries read ──

  Stream<List<ExtraordinaryEventEntry>> watchEntries(
    int eventId, {
    DateTime? through,
  }) {
    final query = _db.select(_db.extraordinaryEventEntries)..where((e) => e.eventId.equals(eventId));
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((e) => e.date.isSmallerThanValue(endExclusive));
    }
    query.orderBy([(e) => OrderingTerm.asc(e.date)]);
    return query.watch();
  }

  Future<List<ExtraordinaryEventEntry>> getEntries(
    int eventId, {
    DateTime? through,
  }) {
    final query = _db.select(_db.extraordinaryEventEntries)..where((e) => e.eventId.equals(eventId));
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((e) => e.date.isSmallerThanValue(endExclusive));
    }
    query.orderBy([(e) => OrderingTerm.asc(e.date)]);
    return query.get();
  }

  // ── Stats ──

  Stream<Map<int, ExtraordinaryEventStats>> watchStatsForAll({
    DateTime? through,
  }) {
    // Driven by the multi-table trigger, not by a select over
    // `extraordinary_events`: allocated/remaining are derived from the entries
    // and buffer tables, so keying off the events table alone left these
    // figures stale until the next restart whenever an entry was added or
    // deleted. (`readsFrom` on the inner one-shot `.get()`s below cannot help
    // — it is only honoured by `.watch()`.)
    return watchAdjustmentRevision().asyncMap((_) async {
      var events = await (_db.select(_db.extraordinaryEvents)..where((e) => e.isActive.equals(true))).get();
      final endExclusive = _throughEndExclusive(through);
      if (endExclusive != null) {
        events = events.where((e) => e.eventDate.isBefore(endExclusive)).toList();
      }
      if (events.isEmpty) return <int, ExtraordinaryEventStats>{};

      final ids = events.map((e) => e.id).toList();
      final placeholders = ids.map((_) => '?').join(', ');
      final bounded = through != null;

      // Batch query: entry stats per event (use absolute amounts for allocated total)
      final entryStats = await _db
          .customSelect(
            'SELECT event_id, COUNT(*) AS cnt, '
            'COALESCE(SUM(ABS(amount)), 0.0) AS total_allocated, '
            'MIN(date) AS first_date, MAX(date) AS last_date '
            'FROM extraordinary_event_entries '
            'WHERE event_id IN ($placeholders) '
            "${bounded ? 'AND date < ? ' : ''}"
            'GROUP BY event_id',
            variables: [
              for (final id in ids) Variable.withInt(id),
              ..._throughVars(through),
            ],
            readsFrom: {_db.extraordinaryEventEntries},
          )
          .get();

      final entryStatsMap = <int, QueryRow>{};
      for (final row in entryStats) {
        entryStatsMap[row.read<int>('event_id')] = row;
      }

      // Reimbursement totals per linked buffer
      final bufferIds = events.where((e) => e.bufferId != null).map((e) => e.bufferId!).toList();

      final reimbursedMap = <int, double>{};
      if (bufferIds.isNotEmpty) {
        final bufPlaceholders = bufferIds.map((_) => '?').join(', ');
        final reimbRows = await _db
            .customSelect(
              // Net reimbursement: refunds (negative entries) reduce the total;
              // SUM(ABS) would double-count them. See _totalReimbursed.
              'SELECT buffer_id, COALESCE(ABS(SUM(amount)), 0.0) AS total '
              'FROM buffer_transactions '
              'WHERE buffer_id IN ($bufPlaceholders) AND is_reimbursement = 1 '
              "${bounded ? 'AND value_date < ? ' : ''}"
              'GROUP BY buffer_id',
              variables: [
                for (final id in bufferIds) Variable.withInt(id),
                ..._throughVars(through),
              ],
              readsFrom: {_db.bufferTransactions},
            )
            .get();
        for (final row in reimbRows) {
          reimbursedMap[row.read<int>('buffer_id')] = row.read<double>('total');
        }
      }

      final result = <int, ExtraordinaryEventStats>{};
      for (final ev in events) {
        final eRow = entryStatsMap[ev.id];
        final cnt = eRow?.read<int>('cnt') ?? 0;
        final totalAllocated = eRow?.read<double>('total_allocated') ?? 0.0;
        final firstDate = cnt > 0 ? DateTime.fromMillisecondsSinceEpoch(eRow!.read<int>('first_date') * 1000) : null;
        final lastDate = cnt > 0 ? DateTime.fromMillisecondsSinceEpoch(eRow!.read<int>('last_date') * 1000) : null;
        final reimbursed = ev.bufferId != null ? (reimbursedMap[ev.bufferId!] ?? 0.0) : 0.0;
        final remaining = (ev.totalAmount - totalAllocated).clamp(0.0, double.infinity).toDouble();

        result[ev.id] = ExtraordinaryEventStats(
          entryCount: cnt,
          firstDate: firstDate,
          lastDate: lastDate,
          totalAmount: ev.totalAmount,
          totalAllocated: totalAllocated,
          remaining: remaining,
          totalReimbursed: reimbursed,
        );
      }
      return result;
    });
  }

  static DateTime? _throughEndExclusive(DateTime? through) {
    if (through == null) return null;
    return DateTime(
      through.year,
      through.month,
      through.day,
    ).add(const Duration(days: 1));
  }

  static List<Variable<int>> _throughVars(DateTime? through) {
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive == null) return const [];
    return [Variable.withInt(endExclusive.millisecondsSinceEpoch ~/ 1000)];
  }

  // ── Buffer linking (spread treatment only) ──

  Future<int> createLinkedBuffer(int eventId) async {
    final event = await getById(eventId);
    if (event.treatment != EventTreatment.spread) {
      throw StateError('Buffers are only supported on spread events');
    }
    _log.info('createLinkedBuffer: event=$eventId (${event.name})');
    final bufferId = await _db
        .into(_db.buffers)
        .insert(
          BuffersCompanion.insert(
            name: event.name,
            linkedEventId: Value(eventId),
          ),
        );
    await (_db.update(
      _db.extraordinaryEvents,
    )..where((e) => e.id.equals(eventId))).write(ExtraordinaryEventsCompanion(bufferId: Value(bufferId)));
    return bufferId;
  }
}
