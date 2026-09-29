// Per-account transactions, per-asset events and the wizard's merchant groups
// are released once nothing shows them: they used to stay alive for the whole
// session, one live query per account / asset / wizard scope ever opened,
// re-run on every write. While listened to they deliver as before.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int account;
  late int asset;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    account = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    asset = await AssetService(db).create(name: 'World', currency: 'EUR', intermediaryId: broker);
    final day = DateTime(2024, 3, 10);
    final n = TransactionClassifierService.normalize(description: 'Esselunga', amount: -20);
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account,
            operationDate: day,
            valueDate: day,
            amount: -20,
            description: const Value('Esselunga'),
            merchantKey: Value(n.merchantKey),
          ),
        );
    await AssetEventService(db).create(assetId: asset, date: day, type: EventType.buy, quantity: 1, amount: 100, currency: 'EUR');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Listens to [provider] until it delivers, checks the value, stops
  /// listening, and reports whether the provider is still alive afterwards.
  Future<bool> aliveAfterUse<T>(ProviderBase<AsyncValue<T>> provider, void Function(T value) check) async {
    final delivered = <T>[];
    final sub = container.listen<AsyncValue<T>>(provider, (_, next) {
      if (next case AsyncData(:final value)) delivered.add(value);
    }, fireImmediately: true);
    for (var i = 0; i < 50 && delivered.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(delivered, isNotEmpty, reason: 'delivers while listened to');
    check(delivered.last);
    sub.close();
    await container.pump();
    return container.exists(provider);
  }

  test("an account's transactions are released once nothing shows the account", () async {
    final alive = await aliveAfterUse(accountTransactionsProvider(account), (rows) => expect(rows.map((t) => t.description), ['Esselunga']));
    expect(alive, isFalse);
  });

  test("an asset's events are released once nothing shows the asset", () async {
    final alive = await aliveAfterUse(assetEventsProvider(asset), (events) => expect(events.map((e) => e.type), [EventType.buy]));
    expect(alive, isFalse);
  });

  test("the wizard's merchant groups are released once the wizard is gone", () async {
    final alive = await aliveAfterUse(uncategorizedGroupsProvider(null), (groups) => expect(groups.map((g) => g.merchantKey), ['ESSELUNGA']));
    expect(alive, isFalse);
  });
}
