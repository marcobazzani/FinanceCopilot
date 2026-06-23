import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/services/providers/providers.dart';

/// Mixin for a detail screen's [ConsumerState] that publishes a description of
/// what the screen shows to the AI assistant (via [aiDetailContextProvider])
/// while it is the top route, and restores the previous value when popped.
///
/// LIFO save/restore makes nested detail screens correct (push child saves the
/// parent's value; popping the child restores it). The value is written after
/// the first frame (so a provider is never modified during build) and is read
/// only by the chat controller at send time, so toggling it triggers no
/// rebuilds.
///
/// `ref` is unsafe inside [dispose], so the [ProviderContainer] captured while
/// mounted is used there instead (guarded — during a full widget-tree teardown
/// the container is gone and there is nothing to restore).
mixin AiViewContextState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// What this screen displays, for the AI's context. Null = publish nothing.
  String? get aiDetailContext;

  ProviderContainer? _container;
  String? _prev;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = aiDetailContext;
      if (ctx == null || ctx.isEmpty) return;
      _container = ProviderScope.containerOf(context, listen: false);
      _prev = _container!.read(aiDetailContextProvider);
      _container!.read(aiDetailContextProvider.notifier).state = ctx;
      _applied = true;
    });
  }

  @override
  void dispose() {
    if (_applied && _container != null) {
      final container = _container!;
      final prev = _prev;
      // Riverpod forbids modifying a provider during a lifecycle method
      // (dispose), so restore on the next tick — by then the pop is done and
      // the scope is settled. If the whole tree (and scope) is being torn down,
      // the container is gone and there is nothing to restore.
      Future(() {
        try {
          container.read(aiDetailContextProvider.notifier).state = prev;
        } catch (_) {
          // ProviderScope disposed with the tree — nothing to restore.
        }
      });
    }
    super.dispose();
  }

  /// Re-publishes [aiDetailContext] after in-screen state changes (e.g. an
  /// internal tab switch). No-op until the initial publish has happened.
  void updateAiContext() {
    if (!_applied || !mounted) return;
    ref.read(aiDetailContextProvider.notifier).state = aiDetailContext;
  }
}
