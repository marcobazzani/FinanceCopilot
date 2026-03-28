import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../database/providers.dart';
import 'enable_banking_config.dart';
import 'enable_banking_service.dart';

/// The Enable Banking service instance.
final enableBankingServiceProvider = Provider<EnableBankingService>((ref) {
  return EnableBankingService(ref.watch(databaseProvider));
});

/// Whether Open Banking is configured (has credentials).
final openBankingConfiguredProvider = FutureProvider<bool>((ref) async {
  final config = await EnableBankingConfig.load();
  return config != null;
});

/// Current config (reactive — invalidated after setup/session changes).
final openBankingConfigProvider = StateProvider<EnableBankingConfig?>((ref) {
  return null;
});
