import 'package:flutter/widgets.dart';

/// Root navigator key for the app's [MaterialApp]. The AI chat overlay is
/// rendered in `MaterialApp.builder` — above the Navigator so it floats over
/// every route (including pushed detail screens) — which means it has no
/// Navigator ancestor of its own. This key lets it reach a Navigator context
/// when it needs one (e.g. to open the Settings dialog).
final rootNavigatorKey = GlobalKey<NavigatorState>();
