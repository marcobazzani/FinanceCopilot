import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('CapexService');

class CapexStats {
  final int entryCount;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final double totalAmount;
  final double totalSpread;
  final double remaining;
  final double totalReimbursed;

  const CapexStats({
    required this.entryCount,
    this.firstDate,
    this.lastDate,
    required this.totalAmount,
    required this.totalSpread,
    required this.remaining,
    this.totalReimbursed = 0,
  });
}

class CapexService {
  final AppDatabase _db;

  CapexService(this._db);

  // ── Schedule CRUD ──

  Stream<List<DepreciationSchedule>> watchAll() {
    return (_db.select(_db.depreciationSchedules)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => OrderingTerm.desc(s.startDate)]))
        .watch();
  }

  Future<List<DepreciationSchedule>> getAll() {
    return (_db.select(_db.depreciationSchedules)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => OrderingTerm.desc(s.startDate)]))
        .get();
  }

  Future<DepreciationSchedule> getById(int id) {
    return (_db.select(_db.depreciationSchedules)
          ..where((s) => s.id.equals(id)))
        .getSingle();
  }

  Stream<DepreciationSchedule> watchById(int id) {
    return (_db.select(_db.depreciationSchedules)
          ..where((s) => s.id.equals(id)))
        .watchSingle();
  }

  Future<int> create({
    required String name,
    required double totalAmount,
    String currency = 'EUR',
    required DateTime startDate,
    required DateTime endDate,
    DateTime? expenseDate,
    StepFrequency stepFrequency = StepFrequency.monthly,
  }) async {
    _log.info('create: name=$name, amount=$totalAmount, expense=${expenseDate ?? 'none'}, '
        '$startDate→$endDate, freq=${stepFrequency.name}');
    final id = await _db.into(_db.depreciationSchedules).insert(
      DepreciationSchedulesCompanion.insert(
        assetName: name,
        assetCategory: '',
        totalAmount: totalAmount,
        currency: Value(currency),
        method: DepreciationMethod.linear,
        startDate: startDate,
        endDate: endDate,
        expenseDate: Value(expenseDate),
        usefulLifeMonths: _monthsBetween(startDate, endDate),
        direction: DepreciationDirection.forward,
        stepFrequency: Value(stepFrequency),
      ),
    );
    await generateEntries(id);
    return id;
  }

  Future<bool> update(int id, DepreciationSchedulesCompanion companion) async {
    _log.info('update: id=$id');
    final rows = await (_db.update(_db.depreciationSchedules)
          ..where((s) => s.id.equals(id)))
        .write(companion.copyWith(updatedAt: Value(DateTime.now())));
    if (rows > 0) await generateEntries(id);
    return rows > 0;
  }

  Future<int> delete(int id) async {
    _log.warning('delete: schedule id=$id');
    final schedule = await getById(id);
    if (schedule.bufferId != null) {
      await (_db.delete(_db.bufferTransactions)..where((t) => t.bufferId.equals(schedule.bufferId!))).go();
      await (_db.delete(_db.buffers)..where((b) => b.id.equals(schedule.bufferId!))).go();
    }
    await (_db.delete(_db.depreciationEntries)..where((e) => e.scheduleId.equals(id))).go();
    return (_db.delete(_db.depreciationSchedules)..where((s) => s.id.equals(id))).go();
  }

  // ── Entry generation ──
  // Entries reflect (totalAmount - reimbursements) spread across steps.

  Future<void> generateEntries(int scheduleId) async {
    final schedule = await getById(scheduleId);
    final dates = computeStepDates(schedule.startDate, schedule.endDate, schedule.stepFrequency);
    if (dates.isEmpty) return;

    // Subtract reimbursements from the amount to spread
    final reimbursed = await _totalReimbursed(schedule);
    final amountToSpread = schedule.totalAmount - reimbursed;
    final stepAmount = amountToSpread / dates.length;
    _log.info('generateEntries: scheduleId=$scheduleId, ${dates.length} steps, '
        '${stepAmount.toStringAsFixed(2)} each (total=${schedule.totalAmount}, reimbursed=$reimbursed)');

    await _db.transaction(() async {
      await (_db.delete(_db.depreciationEntries)..where((e) => e.scheduleId.equals(scheduleId))).go();

      var cumulative = 0.0;
      for (final date in dates) {
        cumulative += stepAmount;
        final remaining = amountToSpread - cumulative;
        await _db.into(_db.depreciationEntries).insert(
          DepreciationEntriesCompanion.insert(
            scheduleId: scheduleId,
            date: date,
            amount: stepAmount,
            cumulative: cumulative,
            remaining: remaining.abs() < 0.01 ? 0 : remaining,
          ),
        );
      }
    });
  }

  Future<double> _totalReimbursed(DepreciationSchedule schedule) async {
    if (schedule.bufferId == null) return 0;
    final txns = await (_db.select(_db.bufferTransactions)
          ..where((t) => t.bufferId.equals(schedule.bufferId!))
          ..where((t) => t.isReimbursement.equals(true)))
        .get();
    var total = 0.0;
    for (final t in txns) {
      total += t.amount.abs();
    }
    return total;
  }

  // ── Entries read ──

  Stream<List<DepreciationEntry>> watchEntries(int scheduleId) {
    return (_db.select(_db.depreciationEntries)
          ..where((e) => e.scheduleId.equals(scheduleId))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .watch();
  }

  Future<List<DepreciationEntry>> getEntries(int scheduleId) {
    return (_db.select(_db.depreciationEntries)
          ..where((e) => e.scheduleId.equals(scheduleId))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();
  }

  // ── Stats ──

  Stream<Map<int, CapexStats>> watchStatsForAll() {
    final scheduleStream = (_db.select(_db.depreciationSchedules)
          ..where((s) => s.isActive.equals(true)))
        .watch();

    return scheduleStream.asyncMap((schedules) async {
      final result = <int, CapexStats>{};
      for (final s in schedules) {
        final entries = await getEntries(s.id);
        final reimbursed = await _totalReimbursed(s);
        result[s.id] = CapexStats(
          entryCount: entries.length,
          firstDate: entries.isNotEmpty ? entries.first.date : null,
          lastDate: entries.isNotEmpty ? entries.last.date : null,
          totalAmount: s.totalAmount,
          totalSpread: entries.fold(0.0, (sum, e) => sum + e.amount),
          remaining: entries.isNotEmpty ? entries.last.remaining : s.totalAmount,
          totalReimbursed: reimbursed,
        );
      }
      return result;
    });
  }

  // ── Buffer linking for reimbursements ──

  Future<int> createLinkedBuffer(int scheduleId) async {
    final schedule = await getById(scheduleId);
    _log.info('createLinkedBuffer: schedule=$scheduleId (${schedule.assetName})');
    final bufferId = await _db.into(_db.buffers).insert(
      BuffersCompanion.insert(
        name: schedule.assetName,
        linkedDepreciationId: Value(scheduleId),
      ),
    );
    await (_db.update(_db.depreciationSchedules)..where((s) => s.id.equals(scheduleId)))
        .write(DepreciationSchedulesCompanion(bufferId: Value(bufferId)));
    return bufferId;
  }

  // ── Helpers (public for preview) ──

  /// Advance a date by [months], clamping the day to the last day of the target month.
  static DateTime _addMonths(DateTime dt, int months) {
    final targetMonth = dt.month + months;
    final targetYear = dt.year + (targetMonth - 1) ~/ 12;
    final normalizedMonth = ((targetMonth - 1) % 12) + 1;
    // Clamp day to last day of target month
    final lastDay = DateTime(targetYear, normalizedMonth + 1, 0).day;
    return DateTime(targetYear, normalizedMonth, dt.day.clamp(1, lastDay));
  }

  static DateTime _advanceStep(DateTime current, StepFrequency freq) {
    return switch (freq) {
      StepFrequency.weekly => current.add(const Duration(days: 7)),
      StepFrequency.monthly => _addMonths(current, 1),
      StepFrequency.quarterly => _addMonths(current, 3),
      StepFrequency.yearly => _addMonths(current, 12),
    };
  }

  static DateTime _retreatStep(DateTime current, StepFrequency freq) {
    return switch (freq) {
      StepFrequency.weekly => current.subtract(const Duration(days: 7)),
      StepFrequency.monthly => _addMonths(current, -1),
      StepFrequency.quarterly => _addMonths(current, -3),
      StepFrequency.yearly => _addMonths(current, -12),
    };
  }

  static List<DateTime> computeStepDates(DateTime start, DateTime end, StepFrequency freq) {
    final dates = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final endNorm = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endNorm)) {
      dates.add(current);
      current = _advanceStep(current, freq);
    }
    return dates;
  }

  static DateTime computeEndDate(DateTime start, int stepCount, StepFrequency freq) {
    var current = DateTime(start.year, start.month, start.day);
    for (var i = 0; i < stepCount - 1; i++) {
      current = _advanceStep(current, freq);
    }
    return current;
  }

  static DateTime computeStartDate(DateTime end, int stepCount, StepFrequency freq) {
    var current = DateTime(end.year, end.month, end.day);
    for (var i = 0; i < stepCount - 1; i++) {
      current = _retreatStep(current, freq);
    }
    return current;
  }

  int _monthsBetween(DateTime a, DateTime b) {
    return (b.year - a.year) * 12 + (b.month - a.month);
  }
}
