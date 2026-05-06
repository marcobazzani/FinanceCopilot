import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'providers/providers.dart';
import '../utils/logger.dart';

final _log = getLogger('RefreshService');

/// Whether a full refresh (market data + FX + compositions) is currently
/// running. Watched by the AppBar refresh button to show its spinner and used
/// as a re-entrancy guard so that pull-to-refresh and the AppBar button never
/// run concurrently.
final isSyncingProvider = StateProvider<bool>((ref) => false);

/// Network availability check. Override in tests to bypass real DNS lookup.
final refreshNetworkCheckProvider = Provider<Future<bool> Function()>((ref) {
  return () => ref.read(networkMonitorProvider).check();
});

/// Step 1 of a manual refresh: pull market prices + FX rates in parallel,
/// then bump [priceRefreshCounter] so dependent UI rebuilds. Override in
/// tests to skip the real network calls.
final refreshMarketDataStepProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await Future.wait([
      ref.read(marketPriceServiceProvider).syncPrices(forceToday: true),
      ref.read(exchangeRateServiceProvider).syncRates(force: true),
    ]);
    ref.read(priceRefreshCounter.notifier).state++;
  };
});

/// Step 2 of a manual refresh: pull asset composition data. Override in
/// tests to skip the real network call.
final refreshCompositionsStepProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(compositionServiceProvider).syncCompositions();
});

/// Runs the full manual refresh sequence: network status check, then market
/// prices + FX rates in parallel, then asset compositions. Each step is
/// best-effort -- failures are logged and don't block subsequent steps.
///
/// Returns immediately if a refresh is already in progress.
final manualRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (ref.read(isSyncingProvider)) return;
    ref.read(isSyncingProvider.notifier).state = true;
    try {
      final online = await ref.read(refreshNetworkCheckProvider)();
      ref.read(networkOnlineProvider.notifier).state = online;

      _log.info('Manual refresh: syncing market data...');
      try {
        await ref.read(refreshMarketDataStepProvider)();
      } catch (e) {
        _log.warning('Manual refresh: market sync failed: $e');
      }

      try {
        await ref.read(refreshCompositionsStepProvider)();
      } catch (e) {
        _log.warning('Manual refresh: composition sync failed: $e');
      }
    } catch (e) {
      _log.warning('Manual refresh error: $e');
    } finally {
      ref.read(isSyncingProvider.notifier).state = false;
    }
  };
});
