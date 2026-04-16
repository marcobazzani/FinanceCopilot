import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';
import '../utils/schedule_math.dart' as schedule_math;

final _log = getLogger('ExtraordinaryEventService');

class ExtraordinaryEventStats {
  final int entryCount;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final double totalAmount;
  final double totalAllocated;    // sum of |entry.amount| for this event
  final double remaining;          // totalAmount − totalAllocated (>=0 expected)
  final double totalReimbursed;    // spread+buffer only

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

  Stream<List<ExtraordinaryEvent>> watchAll() {
    return (_db.select(_db.extraordinaryEvents)
          ..where((e) => e.isActive.equals(true))
          ..orderBy([(e) => OrderingTerm.desc(e.eventDate)]))
        .watch();
  }

  Future<List<ExtraordinaryEvent>> getAll() {
    return (_db.select(_db.extraordinaryEvents)
          ..where((e) => e.isActive.equals(true))
          ..orderBy([(e) => OrderingTerm.desc(e.eventDate)]))
        .get();
  }

  Future<ExtraordinaryEvent> getById(int id) {
    return (_db.select(_db.extraordinaryEvents)
          ..where((e) => e.id.equals(id)))
        .getSingle();
  }

  Stream<ExtraordinaryEvent> watchById(int id) {
    return (_db.select(_db.extraordinaryEvents)
          ..where((e) => e.id.equals(id)))
        .watchSingle();
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
  }) async {
    if (treatment == EventTreatment.spread) {
      if (stepFrequency == null || spreadStart == null || spreadEnd == null) {
        throw ArgumentError('spread treatment requires stepFrequency, spreadStart, spreadEnd');
      }
    }
    _log.info('create: name=$name, $direction/$treatment, amount=$totalAmount');
    final id = await _db.into(_db.extraordinaryEvents).insert(
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
      ),
    );
    if (treatment == EventTreatment.spread) {
      await generateScheduledEntries(id);
    }
    return id;
  }

  Future<bool> update(int id, ExtraordinaryEventsCompanion companion) async {
    _log.info('update: id=$id');
    final rows = await (_db.update(_db.extraordinaryEvents)
          ..where((e) => e.id.equals(id)))
        .write(companion.copyWith(updatedAt: Value(DateTime.now())));
    if (rows > 0) {
      final event = await getById(id);
      if (event.treatment == EventTreatment.spread) {
        await generateScheduledEntries(id);
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
    _log.info('generateScheduledEntries: event=$eventId, ${dates.length} steps, '
        'signedStep=$signedStep');

    await _db.transaction(() async {
      await (_db.delete(_db.extraordinaryEventEntries)
            ..where((e) =>
                e.eventId.equals(eventId) &
                e.entryKind.equalsValue(EventEntryKind.scheduled)))
          .go();

      var cumulative = 0.0;
      for (final date in dates) {
        cumulative += stepAmount;
        final remaining = amountToSpread - cumulative;
        await _db.into(_db.extraordinaryEventEntries).insert(
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
    final result = await _db.customSelect(
      'SELECT COALESCE(SUM(ABS(amount)), 0.0) AS total '
      'FROM buffer_transactions '
      'WHERE buffer_id = ? AND is_reimbursement = 1',
      variables: [Variable.withInt(event.bufferId!)],
      readsFrom: {_db.bufferTransactions},
    ).getSingle();
    return result.read<double>('total');
  }

  // ── Manual entry CRUD (instant treatment primarily; also available for spread) ──
  // The user-supplied [amount] is positive; we sign it based on event direction.

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
    return _db.into(_db.extraordinaryEventEntries).insert(
      ExtraordinaryEventEntriesCompanion.insert(
        eventId: eventId,
        date: date,
        amount: signed,
        entryKind: EventEntryKind.manual,
        description: Value(description),
      ),
    );
  }

  Future<void> updateManualEntry(int entryId, ExtraordinaryEventEntriesCompanion companion) async {
    await (_db.update(_db.extraordinaryEventEntries)
          ..where((e) => e.id.equals(entryId)))
        .write(companion);
  }

  Future<void> deleteEntry(int entryId) async {
    await (_db.delete(_db.extraordinaryEventEntries)..where((e) => e.id.equals(entryId))).go();
  }

  // ── Entries read ──

  Stream<List<ExtraordinaryEventEntry>> watchEntries(int eventId) {
    return (_db.select(_db.extraordinaryEventEntries)
          ..where((e) => e.eventId.equals(eventId))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .watch();
  }

  Future<List<ExtraordinaryEventEntry>> getEntries(int eventId) {
    return (_db.select(_db.extraordinaryEventEntries)
          ..where((e) => e.eventId.equals(eventId))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();
  }

  // ── Stats ──

  Stream<Map<int, ExtraordinaryEventStats>> watchStatsForAll() {
    final eventStream = (_db.select(_db.extraordinaryEvents)
          ..where((e) => e.isActive.equals(true)))
        .watch();

    return eventStream.asyncMap((events) async {
      if (events.isEmpty) return <int, ExtraordinaryEventStats>{};

      final ids = events.map((e) => e.id).toList();
      final placeholders = ids.map((_) => '?').join(', ');

      // Batch query: entry stats per event (use absolute amounts for allocated total)
      final entryStats = await _db.customSelect(
        'SELECT event_id, COUNT(*) AS cnt, '
        'COALESCE(SUM(ABS(amount)), 0.0) AS total_allocated, '
        'MIN(date) AS first_date, MAX(date) AS last_date '
        'FROM extraordinary_event_entries '
        'WHERE event_id IN ($placeholders) '
        'GROUP BY event_id',
        variables: [for (final id in ids) Variable.withInt(id)],
        readsFrom: {_db.extraordinaryEventEntries},
      ).get();

      final entryStatsMap = <int, QueryRow>{};
      for (final row in entryStats) {
        entryStatsMap[row.read<int>('event_id')] = row;
      }

      // Reimbursement totals per linked buffer
      final bufferIds = events
          .where((e) => e.bufferId != null)
          .map((e) => e.bufferId!)
          .toList();

      final reimbursedMap = <int, double>{};
      if (bufferIds.isNotEmpty) {
        final bufPlaceholders = bufferIds.map((_) => '?').join(', ');
        final reimbRows = await _db.customSelect(
          'SELECT buffer_id, COALESCE(SUM(ABS(amount)), 0.0) AS total '
          'FROM buffer_transactions '
          'WHERE buffer_id IN ($bufPlaceholders) AND is_reimbursement = 1 '
          'GROUP BY buffer_id',
          variables: [for (final id in bufferIds) Variable.withInt(id)],
          readsFrom: {_db.bufferTransactions},
        ).get();
        for (final row in reimbRows) {
          reimbursedMap[row.read<int>('buffer_id')] = row.read<double>('total');
        }
      }

      final result = <int, ExtraordinaryEventStats>{};
      for (final ev in events) {
        final eRow = entryStatsMap[ev.id];
        final cnt = eRow?.read<int>('cnt') ?? 0;
        final totalAllocated = eRow?.read<double>('total_allocated') ?? 0.0;
        final firstDate = cnt > 0
            ? DateTime.fromMillisecondsSinceEpoch(eRow!.read<int>('first_date') * 1000)
            : null;
        final lastDate = cnt > 0
            ? DateTime.fromMillisecondsSinceEpoch(eRow!.read<int>('last_date') * 1000)
            : null;
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

  // ── Buffer linking (spread treatment only) ──

  Future<int> createLinkedBuffer(int eventId) async {
    final event = await getById(eventId);
    if (event.treatment != EventTreatment.spread) {
      throw StateError('Buffers are only supported on spread events');
    }
    _log.info('createLinkedBuffer: event=$eventId (${event.name})');
    final bufferId = await _db.into(_db.buffers).insert(
      BuffersCompanion.insert(
        name: event.name,
        // NB: linkedDepreciationId kept on Buffers for backward compat during
        // Phase 1. In Phase 3 the column is renamed to linked_event_id.
        linkedDepreciationId: Value(eventId),
      ),
    );
    await (_db.update(_db.extraordinaryEvents)..where((e) => e.id.equals(eventId)))
        .write(ExtraordinaryEventsCompanion(bufferId: Value(bufferId)));
    return bufferId;
  }
}
