// Pins what the stream providers hand the screens, so their dependencies can
// be watched before any await (not one after another, and never on a ref an
// await may have outlived) without changing a value:
//  * classification progress and merchant groups, valued in the base currency;
//  * the default charts, expanded against the active accounts and assets;
//  * the pillar fractions (assigned per pillar, unassigned per asset).

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/charts/default_charts_loader.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // the default charts come from the asset bundle

  late AppDatabase db;
  late ProviderContainer container;
  late int account;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    account = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// The first value [provider] resolves to, read while listened to.
  Future<T> first<T>(ProviderListenable<Future<T>> provider) async {
    final sub = container.listen(provider, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }

  Future<void> tx(String description, double amount, {String currency = 'EUR', int? categoryId}) {
    final n = TransactionClassifierService.normalize(description: description, amount: amount);
    final day = DateTime(2024, 3, 10);
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account,
            operationDate: day,
            valueDate: day,
            amount: amount,
            description: Value(description),
            currency: Value(currency),
            categoryId: Value(categoryId),
            merchantKey: Value(n.merchantKey),
            counterparty: Value(n.counterparty),
            entryKind: Value(n.entryKind),
          ),
        );
  }

  test('classification progress and merchant groups are valued in the base currency', () async {
    final groceries = await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle();
    await tx('Esselunga', -20, categoryId: groceries.id);
    await tx('Esselunga', -30);
    await tx('Dentist', -100, currency: 'USD');
    await db
        .into(db.exchangeRates)
        .insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: DateTime(2024, 1, 1), rate: 0.5));

    for (final scope in [null, account]) {
      final progress = await first(classificationProgressProvider(scope).future);
      expect((progress.total, progress.categorized, progress.fxExcluded), (3, 1, 0), reason: 'scope $scope');
      expect((progress.totalAmount, progress.categorizedAmount, progress.baseCurrency), (100.0, 20.0, 'EUR'), reason: 'scope $scope');

      final groups = await first(uncategorizedGroupsProvider(scope).future);
      expect([for (final g in groups) (g.merchantKey, g.baseTotal)], [('DENTIST', 50.0), ('ESSELUNGA', 30.0)], reason: 'money first');
    }

    final elsewhere = await first(classificationProgressProvider(account + 1).future);
    expect((elsewhere.total, elsewhere.totalAmount), (0, 0.0));
  });

  test('the default charts are expanded against the active accounts and assets only', () async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Closed', isActive: const Value(false)));
    final asset = await AssetService(db).create(name: 'World', currency: 'EUR', intermediaryId: broker);

    final charts = await first(defaultChartsLoadedProvider.future);

    final accounts = await (db.select(db.accounts)..where((a) => a.isActive.equals(true))).get();
    final assets = await (db.select(db.assets)..where((a) => a.id.equals(asset))).get();
    final expected = const DefaultChartsLoader().parse(
      File('assets/default_charts.json').readAsStringSync(),
      activeAccounts: accounts,
      activeAssets: assets,
      activeEvents: const [],
    );
    (String, String, int, String, String?) shape(DashboardChart c) => (c.title, c.widgetType, c.sortOrder, c.seriesJson, c.sourceChartIds);
    expect(charts.map(shape), expected.map(shape));
    expect(charts.any((c) => c.seriesJson.contains('"type":"account","id":$account')), isTrue);
  });

  test('pillar fractions: the assigned share per pillar, the unassigned rest per asset', () async {
    final asset = await AssetService(db).create(name: 'World', currency: 'EUR', intermediaryId: broker);
    await AssetEventService(
      db,
    ).create(assetId: asset, date: DateTime(2024, 1, 5), type: EventType.buy, quantity: 10, amount: 100, currency: 'EUR');
    final pillars = PillarService(db);
    final core = await pillars.create(name: 'Core');
    await pillars.assign(pillarId: core, assetId: asset, qty: 4);

    expect(await first(pillarFractionProvider(core).future), {asset: 0.4});
    expect(await first(unassignedFractionProvider.future), {asset: closeTo(0.6, 1e-12)});
  });
}
