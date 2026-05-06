import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_actions_controller.dart';

/// Wraps a scrollable [child] with a [RefreshIndicator] on Android/iOS so the
/// user can pull down at the top of the view to trigger the same global
/// refresh as the AppBar's refresh action (market prices + FX rates +
/// asset compositions, via [GlobalActionsRegistry.manualRefresh]). On
/// desktop platforms the widget returns [child] unchanged.
///
/// Convention: every primary screen that calls
/// `globalAppBarActions(context, ref)` should also wrap its scrollable body
/// in a [MobilePullToRefresh] with `physics: AlwaysScrollableScrollPhysics()`,
/// so a new view automatically inherits both the global refresh button and
/// the pull-to-refresh gesture.
class MobilePullToRefresh extends ConsumerWidget {
  const MobilePullToRefresh({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return child;
    }
    final reg = ref.watch(globalActionsRegistryProvider);
    return RefreshIndicator(
      onRefresh: () async {
        if (reg == null) return;
        await reg.manualRefresh();
      },
      child: child,
    );
  }
}
