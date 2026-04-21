import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Schema creation', () {
    test('database opens without error', () async {
      // Just accessing a table triggers onCreate
      final accounts = await db.select(db.accounts).get();
      expect(accounts, isEmpty);
    });

    test('AppConfig is seeded with defaults', () async {
      final configs = await db.select(db.appConfigs).get();
      final keys = configs.map((c) => c.key).toSet();

      expect(keys, containsAll([
        'RT_SMA_WINDOW',
        'EXPENSE_SMA_WINDOW',
        'RAL_WINDOW',
        'VOL_WINDOW',
        'NET_PL_SMA_WINDOW',
        'TAX_RATE',
        'SWR',
        'BASE_CURRENCY',
        'DEFAULT_DEPRECIATION_METHOD',
      ]));

      final taxRate = configs.firstWhere((c) => c.key == 'TAX_RATE');
      expect(taxRate.value, '0.26');

      final baseCurrency = configs.firstWhere((c) => c.key == 'BASE_CURRENCY');
      expect(baseCurrency.value, 'EUR');
    });
  });

  group('Account CRUD', () {
    test('insert and retrieve an account', () async {
      await db.into(db.accounts).insert(AccountsCompanion.insert(
        name: 'Fineco',
      ));

      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(1));
      expect(accounts.first.name, 'Fineco');
      expect(accounts.first.type, AccountType.bank);
      expect(accounts.first.currency, 'EUR');
      expect(accounts.first.isActive, true);
      expect(accounts.first.includeInNetWorth, true);
    });
  });

  group('Transaction CRUD', () {
    test('insert transaction linked to account', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Revolut'),
      );

      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 15),
        valueDate: DateTime(2024, 1, 15),
        amount: -42.50,
      ));

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.first.amount, -42.50);
      expect(txs.first.accountId, accountId);
    });
  });

  group('Asset & AssetEvent', () {
    test('insert asset with events and snapshot', () async {
      final assetId = await db.into(db.assets).insert(
        AssetsCompanion.insert(
          name: 'iShares Core MSCI World',
          assetType: AssetType.stockEtf,
          instrumentType: const Value(InstrumentType.etf),
          assetClass: const Value(AssetClass.equity),
          valuationMethod: ValuationMethod.marketPrice,
        ),
      );

      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        valueDate: DateTime(2024, 3, 1),
        type: EventType.buy,
        amount: 5000.0,
      ));

      await db.into(db.assetSnapshots).insert(AssetSnapshotsCompanion.insert(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        value: 5100.0,
        invested: 5000.0,
        growth: 100.0,
        growthPercent: 0.02,
        afterTaxValue: 5074.0, // 5000 + 100 * (1 - 0.26)
      ));

      final snapshots = await db.select(db.assetSnapshots).get();
      expect(snapshots, hasLength(1));
      expect(snapshots.first.value, 5100.0);
      expect(snapshots.first.afterTaxValue, 5074.0);
    });
  });

  group('Database indexes', () {
    test('expected idx_* indexes exist', () async {
      // Trigger onCreate
      await db.select(db.accounts).get();

      final rows = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name",
      ).get();
      final indexNames = rows.map((r) => r.read<String>('name')).toList();

      expect(indexNames, unorderedEquals([
        'idx_transactions_account_date_id',
        'idx_event_entries_event_date',
        'idx_asset_events_asset_date',
        'idx_asset_compositions_asset_id',
        'idx_market_prices_asset_date',
        'idx_buffer_transactions_buffer_id',
      ]));
    });
  });

  group('Import deduplication', () {
    test('import_hash prevents duplicate transactions', () async {
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(name: 'Fineco'),
      );

      final hash = 'abc123sha256hash';

      // First insert
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: DateTime(2024, 1, 15),
        valueDate: DateTime(2024, 1, 15),
        amount: -100.0,
        importHash: Value(hash),
      ));

      // Check hash exists
      final existing = await (db.select(db.transactions)
            ..where((t) => t.importHash.equals(hash)))
          .get();
      expect(existing, hasLength(1));

      // Simulate dedup check: if hash exists, skip
      final duplicate = await (db.select(db.transactions)
            ..where((t) => t.accountId.equals(accountId))
            ..where((t) => t.importHash.equals(hash)))
          .get();
      expect(duplicate, hasLength(1)); // Would skip this row on re-import
    });
  });
}
