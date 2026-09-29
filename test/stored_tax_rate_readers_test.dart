// The default capital-gains tax rate stored under TAX_RATE has one reading,
// shared by its two readers — the settings/dashboard provider and the
// rebalance draft: unset is 26% silently, a number is clamped to [0, 1]
// silently, and a value that does not read as a number is 26% with a warning
// naming it, whichever of the two reads it.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

void main() {
  late AppDatabase db;
  late List<LogRecord> warnings;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    warnings = [];
    final sub = Logger.root.onRecord.where((r) => r.level == Level.WARNING).listen(warnings.add);
    addTearDown(sub.cancel);
  });
  tearDown(() => db.close());

  Future<void> store(String? value) async {
    await (db.delete(db.appConfigs)..where((c) => c.key.equals('TAX_RATE'))).go();
    if (value != null) await db.into(db.appConfigs).insert(AppConfigsCompanion.insert(key: 'TAX_RATE', value: value));
  }

  Future<double> providerRate() async {
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    // Listened to: a provider nobody listens to is paused, its stream too.
    container.listen(defaultTaxRateProvider, (_, _) {});
    return container.read(defaultTaxRateProvider.future);
  }

  /// A draft reads the rate before anything else, pillars or not.
  Future<void> rebalanceRead() => PortfolioRebalanceService(
    db,
  ).buildDraft(scope: const PortfolioRebalanceScope.allAssociatedPillars(), mode: PortfolioRebalanceMode.sellAndBuy, asOf: DateTime(2026, 2, 2));

  List<String> taxRateWarnings() => [
    for (final r in warnings)
      if (r.message.startsWith('TAX_RATE')) r.message,
  ];

  group('pinned', () {
    for (final (stored, rate) in [(null, 0.26), ('0.3', 0.3), ('1.5', 1.0), ('-0.2', 0.0), ('0', 0.0), ('1', 1.0)]) {
      test('stored ${stored == null ? 'nothing' : '"$stored"'}: $rate, silently, for both readers', () async {
        await store(stored);
        expect(await providerRate(), rate);
        await rebalanceRead();
        await pumpEventQueue();
        expect(taxRateWarnings(), isEmpty);
      });
    }

    for (final stored in ['abc', '', '26%', '0,3']) {
      test('stored "$stored": 26%, and each reader warns naming it', () async {
        await store(stored);
        expect(await providerRate(), 0.26);
        await pumpEventQueue();
        expect(taxRateWarnings(), ['TAX_RATE "$stored" is not a number: the default 0.26 applies'], reason: 'the provider read it');

        await rebalanceRead();
        await pumpEventQueue();
        expect(taxRateWarnings(), hasLength(2), reason: 'the rebalance read it too');
        expect(taxRateWarnings().toSet(), hasLength(1), reason: 'the same reading says the same');
      });
    }
  });
}
