import 'dart:async';
import 'dart:io';

import '../utils/logger.dart';

final _log = getLogger('NetworkMonitor');

/// Lightweight network availability monitor.
/// Checks connectivity by resolving a DNS name. When offline, all
/// background sync should be paused to avoid log-spamming 403/520 errors.
class NetworkMonitor {
  bool _online = true;
  DateTime? _lastCheck;
  static const _checkInterval = Duration(seconds: 30);
  static const _offlineBackoff = Duration(minutes: 2);

  bool get isOnline => _online;

  /// Quick connectivity check. Cached for [_checkInterval].
  /// Returns true if network is available.
  Future<bool> check() async {
    final now = DateTime.now();
    final interval = _online ? _checkInterval : _offlineBackoff;
    if (_lastCheck != null && now.difference(_lastCheck!) < interval) {
      return _online;
    }

    try {
      final result = await InternetAddress.lookup('api.github.com')
          .timeout(const Duration(seconds: 5));
      _online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      _online = false;
    } on TimeoutException {
      _online = false;
    } catch (_) {
      _online = false;
    }

    _lastCheck = now;
    if (!_online) _log.info('Network offline');
    return _online;
  }

  /// Mark as offline (e.g. after repeated 403/520 errors).
  void markOffline() {
    if (_online) _log.info('Marked offline due to repeated errors');
    _online = false;
    _lastCheck = DateTime.now();
  }

  /// Force a fresh check on next call.
  void reset() {
    _lastCheck = null;
  }
}
