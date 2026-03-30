import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../database/database.dart';
import '../../database/providers.dart';
import '../../l10n/app_strings.dart';
import '../account_service.dart';
import '../asset_event_service.dart';
import '../asset_service.dart';
import '../buffer_service.dart';
import '../capex_service.dart';
import '../dashboard_chart_service.dart';
import '../income_adjustment_service.dart';
import '../income_service.dart';
import '../exchange_rate_service.dart';
import '../import_config_service.dart';
import '../composition_service.dart';
import '../investing_com_service.dart';
import '../network_monitor.dart';
import '../import_service.dart';
import '../isin_lookup_service.dart';
import '../market_price_service.dart';
import '../intermediary_service.dart';
import '../transaction_service.dart';
import '../../utils/logger.dart';

part 'app_state_providers.dart';
part 'service_providers.dart';
part 'stream_providers.dart';
part 'computed_providers.dart';

final _log = getLogger('Providers');
