import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/refresh_service.dart';

void main() {
  group('manualRefreshProvider', () {
    test('runs market-data step then composition step in order, '
        'flips isSyncingProvider, and bumps priceRefreshCounter via the step',
        () async {
      final calls = <String>[];

      final container = ProviderContainer(overrides: [
        refreshNetworkCheckProvider.overrideWith((_) => () async => true),
        refreshMarketDataStepProvider.overrideWith((ref) => () async {
              calls.add('market-start');
              await Future<void>.delayed(const Duration(milliseconds: 5));
              ref.read(priceRefreshCounter.notifier).state++;
              calls.add('market-done');
            }),
        refreshCompositionsStepProvider.overrideWith((_) => () async {
              calls.add('compositions');
            }),
      ]);
      addTearDown(container.dispose);

      expect(container.read(isSyncingProvider), isFalse);

      final future = container.read(manualRefreshProvider)();
      // Should flip syncing to true synchronously (before awaiting the steps).
      expect(container.read(isSyncingProvider), isTrue);
      await future;

      expect(container.read(isSyncingProvider), isFalse);
      expect(calls, ['market-start', 'market-done', 'compositions']);
      expect(container.read(priceRefreshCounter), 1);
      expect(container.read(networkOnlineProvider), isTrue);
    });

    test('compositions still run when the market step throws, '
        'and isSyncingProvider is reset', () async {
      final calls = <String>[];

      final container = ProviderContainer(overrides: [
        refreshNetworkCheckProvider.overrideWith((_) => () async => true),
        refreshMarketDataStepProvider.overrideWith((_) => () async {
              calls.add('market');
              throw StateError('market boom');
            }),
        refreshCompositionsStepProvider.overrideWith((_) => () async {
              calls.add('compositions');
            }),
      ]);
      addTearDown(container.dispose);

      await container.read(manualRefreshProvider)();

      expect(calls, ['market', 'compositions']);
      expect(container.read(isSyncingProvider), isFalse);
      // Market step threw before bumping the counter -- it must still be 0.
      expect(container.read(priceRefreshCounter), 0);
    });

    test('market step still runs when compositions throws, '
        'and isSyncingProvider is reset', () async {
      final calls = <String>[];

      final container = ProviderContainer(overrides: [
        refreshNetworkCheckProvider.overrideWith((_) => () async => true),
        refreshMarketDataStepProvider.overrideWith((ref) => () async {
              calls.add('market');
              ref.read(priceRefreshCounter.notifier).state++;
            }),
        refreshCompositionsStepProvider.overrideWith((_) => () async {
              calls.add('compositions');
              throw StateError('comp boom');
            }),
      ]);
      addTearDown(container.dispose);

      await container.read(manualRefreshProvider)();

      expect(calls, ['market', 'compositions']);
      expect(container.read(isSyncingProvider), isFalse);
      expect(container.read(priceRefreshCounter), 1);
    });

    test('re-entrant call is a no-op while a refresh is already running',
        () async {
      var marketRuns = 0;
      final marketGate = Completer<void>();

      final container = ProviderContainer(overrides: [
        refreshNetworkCheckProvider.overrideWith((_) => () async => true),
        refreshMarketDataStepProvider.overrideWith((_) => () async {
              marketRuns++;
              await marketGate.future;
            }),
        refreshCompositionsStepProvider.overrideWith((_) => () async {}),
      ]);
      addTearDown(container.dispose);

      final first = container.read(manualRefreshProvider)();
      // Yield once so the first call gets past the guard set + into the await.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(isSyncingProvider), isTrue);

      // Second call should return immediately without running the market step.
      await container.read(manualRefreshProvider)();
      expect(marketRuns, 1);
      expect(container.read(isSyncingProvider), isTrue);

      marketGate.complete();
      await first;
      expect(container.read(isSyncingProvider), isFalse);
      expect(marketRuns, 1);
    });

    test('updates networkOnlineProvider from the network check result',
        () async {
      final container = ProviderContainer(overrides: [
        refreshNetworkCheckProvider.overrideWith((_) => () async => false),
        refreshMarketDataStepProvider.overrideWith((_) => () async {}),
        refreshCompositionsStepProvider.overrideWith((_) => () async {}),
      ]);
      addTearDown(container.dispose);

      // Default is true; flipping it via the refresh proves the wiring works.
      expect(container.read(networkOnlineProvider), isTrue);
      await container.read(manualRefreshProvider)();
      expect(container.read(networkOnlineProvider), isFalse);
    });
  });
}
