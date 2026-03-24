import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../l10n/app_strings.dart';
import '../../services/providers.dart';
import '../../services/tour_service.dart';
import 'spotlight_overlay.dart';

/// Renders the spotlight tour overlay above all app content.
/// Insert via MaterialApp.builder so it sits above pushed routes.
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay> {
  Rect? _targetRect;
  GlobalKey? _lastTargetKey;

  @override
  void initState() {
    super.initState();
    // Re-compute target rect after each frame when tour is active
    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
  }

  void _afterFrame(Duration _) {
    if (!mounted) return;
    _updateTargetRect();
    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
  }

  void _updateTargetRect() {
    final tour = ref.read(tourProvider);
    if (!tour.isActive || !tour.hasSpotlight) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }
    final key = tour.targetKey;
    if (key == null) {
      if (_targetRect != null) setState(() { _targetRect = null; _lastTargetKey = null; });
      return;
    }
    // If target key changed, clear old rect so we don't show stale position
    if (key != _lastTargetKey) {
      _lastTargetKey = key;
      if (_targetRect != null) setState(() => _targetRect = null);
    }
    final renderObj = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderObj == null || !renderObj.attached) {
      // Target not mounted yet (e.g. screen still building) — keep waiting
      return;
    }
    final topLeft = renderObj.localToGlobal(Offset.zero);
    final rect = topLeft & renderObj.size;
    if (rect != _targetRect) {
      setState(() => _targetRect = rect);
    }
  }

  String _messageForStep(TourState tour, AppStrings s) {
    final step = tour.currentStep!;
    final dir = tour.demoCsvDir ?? '';
    return switch (step) {
      TourStep.dbPickerNewProject => s.tourStepNewProject,
      TourStep.navAccounts => s.tourStepNavAccounts,
      TourStep.accountsImportFab => s.tourStepAccountsImport,
      TourStep.txOpenFile => s.tourTxNoFile(dir),
      TourStep.txSkipRows => s.tourTxSkipRows,
      TourStep.txMapDate => s.tourTxMapDate,
      TourStep.txMapAmount => s.tourTxMapAmount,
      TourStep.txMapDescription => s.tourTxMapDescription,
      TourStep.txBalance => s.tourTxBalance,
      TourStep.txDedup => s.tourTxDedup,
      TourStep.txNext => s.tourTxNext,
      TourStep.txConfirm => s.tourImportStep2,
      TourStep.txDone => s.tourImportStep3,
      TourStep.navAssets => s.tourStepNavAssets,
      TourStep.assetsImportFab => s.tourStepAssetsImport,
      TourStep.assetOpenFile => s.tourAssetNoFile(dir),
      TourStep.assetMapAndNext => s.tourAssetMapping,
      TourStep.assetConfirm => s.tourImportStep2,
      TourStep.assetDone => s.tourImportStep3,
      TourStep.navAdjustments => s.tourStepNavAdjustments,
      TourStep.adjustmentsFab => s.tourStepAdjustmentsFab,
      TourStep.navIncome => s.tourStepNavIncome,
      TourStep.incomeImportFab => s.tourStepIncomeImport,
      TourStep.incomeOpenFile => s.tourIncomeNoFile(dir),
      TourStep.incomeMapAndNext => s.tourIncomeMapping,
      TourStep.incomeConfirm => s.tourImportStep2,
      TourStep.incomeDone => s.tourImportStep3,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tour = ref.watch(tourProvider);
    final s = ref.watch(appStringsProvider);

    // Observe import screen state to auto-advance tour steps
    if (tour.isActive) {
      final importStep = ref.watch(importStepProvider);
      final fileLoaded = ref.watch(importFileLoadedProvider);

      // Import screen opened → advance from FAB step to OpenFile step
      if (importStep != null && (tour.currentStep == TourStep.accountsImportFab ||
          tour.currentStep == TourStep.assetsImportFab ||
          tour.currentStep == TourStep.incomeImportFab)) {
        Future.microtask(() => Tour.advance(ref.read(tourProvider.notifier)));
      }

      // File loaded → advance from OpenFile to MapAndNext
      if (fileLoaded && (tour.currentStep == TourStep.txOpenFile ||
          tour.currentStep == TourStep.assetOpenFile ||
          tour.currentStep == TourStep.incomeOpenFile)) {
        Future.microtask(() => Tour.advance(ref.read(tourProvider.notifier)));
      }
      // Moved to confirm step → advance from Next/MapAndNext to Confirm
      if (importStep == 2 && (tour.currentStep == TourStep.txNext ||
          tour.currentStep == TourStep.assetMapAndNext ||
          tour.currentStep == TourStep.incomeMapAndNext)) {
        Future.microtask(() => Tour.advance(ref.read(tourProvider.notifier)));
      }
      // Moved to result step → advance from Confirm to Done
      if (importStep == 3 && (tour.currentStep == TourStep.txConfirm ||
          tour.currentStep == TourStep.assetConfirm ||
          tour.currentStep == TourStep.incomeConfirm)) {
        Future.microtask(() => Tour.advance(ref.read(tourProvider.notifier)));
      }
      // Left import screen → advance from Done to next tour step
      if (importStep == null && (tour.currentStep == TourStep.txDone ||
          tour.currentStep == TourStep.assetDone ||
          tour.currentStep == TourStep.incomeDone)) {
        Future.microtask(() => Tour.advance(ref.read(tourProvider.notifier)));
      }
    }

    return Stack(
      children: [
        widget.child,

        // Spotlight overlay (blocking — for single-button steps)
        if (tour.isActive && tour.hasSpotlight && !tour.isNonBlocking && _targetRect != null)
          Positioned.fill(
            child: SpotlightOverlay(
              targetRect: _targetRect!,
              message: _messageForStep(tour, s),
              skipLabel: s.tourSkip,
              onSkip: () => Tour.cancel(ref.read(tourProvider.notifier), dbPathNotifier: ref.read(dbPathProvider.notifier)),
              onBack: tour.currentStep != TourStep.values.first ? () => Tour.back(ref.read(tourProvider.notifier)) : null,
            ),
          ),

        // Non-blocking spotlight (balloon with arrow, no scrim, user can interact)
        if (tour.isActive && tour.hasSpotlight && tour.isNonBlocking && _targetRect != null)
          Positioned.fill(
            child: SpotlightOverlay(
              targetRect: _targetRect!,
              message: _messageForStep(tour, s),
              skipLabel: s.tourSkip,
              noScrim: true,
              continueLabel: tour.showContinueButton ? s.tourContinue : null,
              onContinue: tour.showContinueButton ? () => Tour.advance(ref.read(tourProvider.notifier)) : null,
              onBack: tour.currentStep != TourStep.values.first ? () => Tour.back(ref.read(tourProvider.notifier)) : null,
              onSkip: () => Tour.cancel(ref.read(tourProvider.notifier), dbPathNotifier: ref.read(dbPathProvider.notifier)),
            ),
          ),

        // "Done" congratulations card
        if (tour.isActive && tour.currentStep == TourStep.done)
          Positioned.fill(
            child: Container(
              color: const Color(0xBB000000),
              alignment: Alignment.center,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.celebration, size: 48, color: Colors.amber),
                      const SizedBox(height: 16),
                      Text(s.tourComplete, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Tour.complete(ref.read(tourProvider.notifier)),
                        child: Text(s.tourGotIt),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
