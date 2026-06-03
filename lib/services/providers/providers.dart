import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:finance_copilot/build_flags.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/default_charts_loader.dart';
import 'package:finance_copilot/services/editable_charts_notifier.dart';
import 'package:finance_copilot/services/account_service.dart';
import 'package:finance_copilot/services/asset_event_service.dart';
import 'package:finance_copilot/services/asset_service.dart';
import 'package:finance_copilot/services/buffer_service.dart';
import 'package:finance_copilot/services/extraordinary_event_service.dart';
import 'package:finance_copilot/services/income_service.dart';
import 'package:finance_copilot/services/exchange_rate_service.dart';
import 'package:finance_copilot/services/import_config_service.dart';
import 'package:finance_copilot/services/composition_service.dart';
import 'package:finance_copilot/services/web_market_data_service.dart';
import 'package:finance_copilot/services/network_monitor.dart';
import 'package:finance_copilot/services/import_service.dart';
import 'package:finance_copilot/services/isin_lookup_service.dart';
import 'package:finance_copilot/services/financial_health_service.dart';
import 'package:finance_copilot/services/market_price_service.dart';
import 'package:finance_copilot/services/intermediary_service.dart';
import 'package:finance_copilot/services/pillar_performance.dart';
import 'package:finance_copilot/services/pillar_scope.dart';
import 'package:finance_copilot/services/pillar_service.dart';
import 'package:finance_copilot/services/portfolio_model_service.dart';
import 'package:finance_copilot/services/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/transaction_service.dart';
import 'package:finance_copilot/utils/asset_value_math.dart';
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/visualization_clock.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show allSeriesDataProvider;

part 'app_state_providers.dart';
part 'service_providers.dart';
part 'stream_providers.dart';
part 'computed_providers.dart';

final _log = getLogger('Providers');
