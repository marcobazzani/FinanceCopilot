import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/refresh_service.dart';

/// Wraps a scrollable [child] with a [RefreshIndicator] on Android/iOS so the
/// user can pull down at the top of the view to trigger a full refresh
/// (market prices, FX rates, asset compositions). On desktop platforms the
/// widget returns [child] unchanged.
///
/// The wrapped scrollable should use [AlwaysScrollableScrollPhysics] so the
/// gesture is available even when the content fits on screen.
class MobilePullToRefresh extends ConsumerWidget {
  const MobilePullToRefresh({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return child;
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(manualRefreshProvider)(),
      child: child,
    );
  }
}
