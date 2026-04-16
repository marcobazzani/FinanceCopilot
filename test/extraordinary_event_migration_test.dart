import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

/// Verifies the v26 -> v27 backfill maps the three known production records
/// correctly:
///   - T-Roc (CAPEX, €20,400, 30-month spread with reimbursements buffer)
///     → outflow/spread event, 30 scheduled entries with negative amounts
///   - Donazione (IncomeAdjustment, €250,000)
///     → inflow/instant event, no entries
///   - Fido (IncomeAdjustment, total=0, one €6,540 expense)
///     → inflow/instant event (preserves legacy bucket placement; keeping
///       it inflow keeps its chart series out of the Cash-line composition)
///
/// Drift's onCreate runs `m.createAll()` for the *current* version, so on a
/// fresh in-memory DB the legacy tables (depreciation_schedules,
/// income_adjustments, etc.) exist but are empty. We populate them directly,
/// then run the v27 backfill SQL statements — the same ones that would run
/// in `onUpgrade(from < 27)` against a real user DB — and assert the new
/// tables reflect the expected mapping.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => await db.close());

  Future<void> insertLegacyFixtures() async {
    // ── T-Roc: CAPEX with buffer (mirrors real prod row) ──
    final bufferId = await db.into(db.buffers).insert(
      BuffersCompanion.insert(name: 'T-Roc'),
    );

    await db.into(db.depreciationSchedules).insert(
      DepreciationSchedulesCompanion.insert(
        assetName: 'T-Roc',
        assetCategory: '',
        totalAmount: 20400,
        currency: const Value('EUR'),
        method: DepreciationMethod.linear,
        startDate: DateTime(2014, 4, 26),
        endDate: DateTime(2016, 9, 26),
        expenseDate: Value(DateTime(2025, 3, 26)),
        usefulLifeMonths: 30,
        direction: DepreciationDirection.forward,
        stepFrequency: const Value(StepFrequency.monthly),
        bufferId: Value(bufferId),
      ),
    );
    // After reimbursement buffer it's 12,400 spread. Simulate 30 entries
    // summing to 12,400 at ~413.33/month.
    for (var i = 0; i < 30; i++) {
      await db.into(db.depreciationEntries).insert(
        DepreciationEntriesCompanion.insert(
          scheduleId: 1,
          date: DateTime(2014, 4, 26).add(Duration(days: i * 30)),
          amount: 12400 / 30,
          cumulative: (i + 1) * (12400 / 30),
          remaining: 12400 - (i + 1) * (12400 / 30),
        ),
      );
    }

    // Link the buffer back to the schedule.
    await (db.update(db.buffers)..where((b) => b.id.equals(bufferId)))
        .write(BuffersCompanion(linkedDepreciationId: Value(1)));

    // ── Donazione: windfall IncomeAdjustment ──
    await db.into(db.incomeAdjustments).insert(
      IncomeAdjustmentsCompanion.insert(
        name: 'Donazione',
        totalAmount: 250000,
        currency: const Value('EUR'),
        incomeDate: DateTime(2025, 12, 15),
      ),
    );

    // ── Fido: zero-amount bucket with one expense (misuse case) ──
    await db.into(db.incomeAdjustments).insert(
      IncomeAdjustmentsCompanion.insert(
        name: 'Fido',
        totalAmount: 0,
        currency: const Value('EUR'),
        incomeDate: DateTime(2026, 4, 5),
      ),
    );
    await db.into(db.incomeAdjustmentExpenses).insert(
      IncomeAdjustmentExpensesCompanion.insert(
        adjustmentId: 2,
        date: DateTime(2026, 3, 2),
        amount: 6540.01,
      ),
    );
  }

  /// Mirrors the v27 backfill block from database.dart onUpgrade(from < 27).
  Future<void> runV27Backfill() async {
    await db.customStatement('''
      INSERT INTO extraordinary_events
        (id, name, direction, treatment, total_amount, currency, event_date,
         transaction_id, step_frequency, spread_start, spread_end, buffer_id,
         is_active, created_at, updated_at)
      SELECT
        id, asset_name, 'outflow', 'spread', total_amount, currency,
        COALESCE(expense_date, start_date),
        transaction_id, step_frequency, start_date, end_date, buffer_id,
        is_active, created_at, updated_at
      FROM depreciation_schedules
    ''');

    await db.customStatement('''
      INSERT INTO extraordinary_event_entries
        (event_id, date, amount, entry_kind, cumulative, remaining)
      SELECT schedule_id, date, -amount, 'scheduled', cumulative, remaining
      FROM depreciation_entries
    ''');

    final oldIas = await db.customSelect(
      'SELECT id, name, total_amount, currency, income_date, is_active, created_at '
      'FROM income_adjustments'
    ).get();
    final idMap = <int, int>{};
    for (final row in oldIas) {
      final oldId = row.read<int>('id');
      final insertResult = await db.customInsert(
        'INSERT INTO extraordinary_events '
        '(name, direction, treatment, total_amount, currency, event_date, '
        ' is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(row.read<String>('name')),
          Variable.withString('inflow'),
          Variable.withString('instant'),
          Variable.withReal(row.read<double>('total_amount')),
          Variable.withString(row.read<String>('currency')),
          Variable.withDateTime(row.read<DateTime>('income_date')),
          Variable.withBool(row.read<bool>('is_active')),
          Variable.withDateTime(row.read<DateTime>('created_at')),
          Variable.withDateTime(row.read<DateTime>('created_at')),
        ],
      );
      idMap[oldId] = insertResult;
    }

    for (final entry in idMap.entries) {
      await db.customStatement(
        'INSERT INTO extraordinary_event_entries '
        '(event_id, date, amount, entry_kind, description, created_at) '
        'SELECT ?, date, amount, ?, description, created_at '
        'FROM income_adjustment_expenses WHERE adjustment_id = ?',
        [entry.value, 'manual', entry.key],
      );
    }
  }

  test('T-Roc maps to outflow/spread with sign-flipped scheduled entries', () async {
    await insertLegacyFixtures();
    await runV27Backfill();

    final troc = await (db.select(db.extraordinaryEvents)
          ..where((e) => e.name.equals('T-Roc')))
        .getSingle();
    expect(troc.direction, EventDirection.outflow);
    expect(troc.treatment, EventTreatment.spread);
    expect(troc.totalAmount, 20400);
    expect(troc.stepFrequency, StepFrequency.monthly);
    expect(troc.bufferId, isNotNull);

    final entries = await (db.select(db.extraordinaryEventEntries)
          ..where((e) => e.eventId.equals(troc.id)))
        .get();
    expect(entries, hasLength(30));
    expect(entries.every((e) => e.entryKind == EventEntryKind.scheduled), isTrue);
    // Scheduled outflow entries must be negative (reduces saving over time).
    expect(entries.every((e) => e.amount < 0), isTrue);
    // Sum of |amount| equals the original spread total (12,400).
    final totalAbs = entries.map((e) => e.amount.abs()).reduce((a, b) => a + b);
    expect(totalAbs, closeTo(12400, 0.01));
  });

  test('Donazione maps to inflow/instant event', () async {
    await insertLegacyFixtures();
    await runV27Backfill();

    final donazione = await (db.select(db.extraordinaryEvents)
          ..where((e) => e.name.equals('Donazione')))
        .getSingle();
    expect(donazione.direction, EventDirection.inflow);
    expect(donazione.treatment, EventTreatment.instant);
    expect(donazione.totalAmount, 250000);
    expect(donazione.eventDate, DateTime(2025, 12, 15));
    expect(donazione.stepFrequency, isNull);
    expect(donazione.spreadStart, isNull);
    expect(donazione.spreadEnd, isNull);

    final entries = await (db.select(db.extraordinaryEventEntries)
          ..where((e) => e.eventId.equals(donazione.id)))
        .get();
    expect(entries, isEmpty);
  });

  test('Fido stays inflow/instant with one positive manual entry', () async {
    await insertLegacyFixtures();
    await runV27Backfill();

    final fido = await (db.select(db.extraordinaryEvents)
          ..where((e) => e.name.equals('Fido')))
        .getSingle();
    // Zero-amount IncomeAdjustments are NOT reclassified — reclassifying
    // would shift the series into the Cash-line composition.
    expect(fido.direction, EventDirection.inflow);
    expect(fido.treatment, EventTreatment.instant);
    expect(fido.totalAmount, 0);

    final entries = await (db.select(db.extraordinaryEventEntries)
          ..where((e) => e.eventId.equals(fido.id)))
        .get();
    expect(entries, hasLength(1));
    expect(entries[0].entryKind, EventEntryKind.manual);
    // Entry amount is preserved positive from the legacy expenses table —
    // matches the inflow/manual sign convention (+amount restores saving).
    expect(entries[0].amount, closeTo(6540.01, 0.001));
    expect(entries[0].date, DateTime(2026, 3, 2));
  });

  test('backfill produces three events total for the fixture', () async {
    await insertLegacyFixtures();
    await runV27Backfill();

    final all = await db.select(db.extraordinaryEvents).get();
    expect(all, hasLength(3));

    final allEntries = await db.select(db.extraordinaryEventEntries).get();
    // 30 scheduled (T-Roc) + 0 (Donazione) + 1 manual (Fido) = 31
    expect(allEntries, hasLength(31));
  });
}
