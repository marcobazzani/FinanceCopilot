import 'dart:io';

import 'package:flutter/widgets.dart';

import '../ui/widgets/tour_keys.dart';
import '../utils/logger.dart';

final _log = getLogger('Tour');

enum TourStep {
  dbPickerNewProject,
  navAccounts,
  accountsImportFab,
  txOpenFile,
  txSkipRows,
  txMapDate,
  txMapAmount,
  txMapDescription,
  txBalance,
  txDedup,
  txNext,
  txConfirm,
  txDone,
  navAssets,
  assetsImportFab,
  assetOpenFile,
  assetMapAndNext,
  assetConfirm,
  assetDone,
  navAdjustments,
  adjustmentsFab,
  createAdjustment,
  navIncome,
  incomeImportFab,
  incomeOpenFile,
  incomeMapAndNext,
  incomeConfirm,
  incomeDone,
  done,
}

class TourState {
  final TourStep? currentStep;
  final String? demoCsvDir;
  final bool isActive;

  const TourState({this.currentStep, this.demoCsvDir, this.isActive = false});

  bool get hasSpotlight {
    if (!isActive || currentStep == null) return false;
    return switch (currentStep!) {
      TourStep.createAdjustment => false,
      _ => true,
    };
  }

  /// Steps where the user needs free interaction (no scrim).
  bool get isNonBlocking {
    if (!isActive || currentStep == null) return false;
    return switch (currentStep!) {
      TourStep.txSkipRows ||
      TourStep.txMapDate ||
      TourStep.txMapAmount ||
      TourStep.txMapDescription ||
      TourStep.txBalance ||
      TourStep.txDedup ||
      TourStep.txNext ||
      TourStep.txConfirm ||
      TourStep.txDone ||
      TourStep.assetMapAndNext ||
      TourStep.assetConfirm ||
      TourStep.assetDone ||
      TourStep.incomeMapAndNext ||
      TourStep.incomeConfirm ||
      TourStep.incomeDone => true,
      _ => false,
    };
  }

  /// Steps that need a Continue button (explanatory steps the user manually advances).
  bool get showContinueButton {
    if (!isActive || currentStep == null) return false;
    return switch (currentStep!) {
      TourStep.txSkipRows ||
      TourStep.txMapDate ||
      TourStep.txMapAmount ||
      TourStep.txMapDescription ||
      TourStep.txBalance ||
      TourStep.txDedup => true,
      _ => false,
    };
  }

  GlobalKey? get targetKey {
    if (!isActive || currentStep == null) return null;
    return switch (currentStep!) {
      TourStep.dbPickerNewProject => TourKeys.newProjectButton,
      TourStep.navAccounts => TourKeys.navAccounts,
      TourStep.accountsImportFab => TourKeys.accountsImportFab,
      TourStep.txOpenFile || TourStep.assetOpenFile || TourStep.incomeOpenFile =>
        TourKeys.importOpenFile,
      TourStep.txSkipRows => TourKeys.importSkipRows,
      TourStep.txMapDate => TourKeys.importMapDate,
      TourStep.txMapAmount => TourKeys.importMapAmount,
      TourStep.txMapDescription => TourKeys.importMapDescription,
      TourStep.txBalance => TourKeys.importBalance,
      TourStep.txDedup => TourKeys.importDedup,
      TourStep.txNext => TourKeys.importNext,
      TourStep.assetMapAndNext || TourStep.incomeMapAndNext =>
        TourKeys.importNext,
      TourStep.txConfirm || TourStep.assetConfirm || TourStep.incomeConfirm =>
        TourKeys.importConfirm,
      TourStep.txDone || TourStep.assetDone || TourStep.incomeDone =>
        TourKeys.importDone,
      TourStep.navAssets => TourKeys.navAssets,
      TourStep.assetsImportFab => TourKeys.assetsImportFab,
      TourStep.navAdjustments => TourKeys.navAdjustments,
      TourStep.adjustmentsFab => TourKeys.adjustmentsFab,
      TourStep.navIncome => TourKeys.navIncome,
      TourStep.incomeImportFab => TourKeys.incomeImportFab,
      TourStep.done => null,
      _ => null,
    };
  }

  int? get targetNavIndex {
    if (!isActive || currentStep == null) return null;
    return switch (currentStep!) {
      TourStep.navAccounts || TourStep.accountsImportFab => 1,
      TourStep.navAssets || TourStep.assetsImportFab => 2,
      TourStep.navAdjustments || TourStep.adjustmentsFab || TourStep.createAdjustment => 3,
      TourStep.navIncome || TourStep.incomeImportFab => 4,
      _ => null,
    };
  }

  String? get demoFilePath {
    if (demoCsvDir == null) return null;
    return switch (currentStep) {
      TourStep.txOpenFile || TourStep.txSkipRows || TourStep.txMapDate ||
      TourStep.txMapAmount || TourStep.txMapDescription ||
      TourStep.txBalance || TourStep.txDedup || TourStep.txNext ||
      TourStep.txConfirm || TourStep.txDone =>
        '$demoCsvDir/demo_transactions.csv',
      TourStep.assetOpenFile || TourStep.assetMapAndNext || TourStep.assetConfirm || TourStep.assetDone =>
        '$demoCsvDir/demo_asset_events.csv',
      TourStep.incomeOpenFile || TourStep.incomeMapAndNext || TourStep.incomeConfirm || TourStep.incomeDone =>
        '$demoCsvDir/demo_income.csv',
      _ => null,
    };
  }

  /// Whether the current step is inside the import screen.
  bool get isImportStep {
    if (!isActive || currentStep == null) return false;
    return switch (currentStep!) {
      TourStep.txOpenFile || TourStep.txSkipRows || TourStep.txMapDate ||
      TourStep.txMapAmount || TourStep.txMapDescription ||
      TourStep.txBalance || TourStep.txDedup || TourStep.txNext ||
      TourStep.txConfirm || TourStep.txDone ||
      TourStep.assetOpenFile || TourStep.assetMapAndNext || TourStep.assetConfirm || TourStep.assetDone ||
      TourStep.incomeOpenFile || TourStep.incomeMapAndNext || TourStep.incomeConfirm || TourStep.incomeDone => true,
      _ => false,
    };
  }

  TourState _next() {
    if (!isActive || currentStep == null) return this;
    final steps = TourStep.values;
    final idx = steps.indexOf(currentStep!);
    if (idx >= steps.length - 1) return this;
    return TourState(
      currentStep: steps[idx + 1],
      demoCsvDir: demoCsvDir,
      isActive: true,
    );
  }
}

class Tour {
  Tour._();

  static void start(dynamic notifier, String csvDir) {
    notifier.state = TourState(
      currentStep: TourStep.dbPickerNewProject,
      demoCsvDir: csvDir,
      isActive: true,
    );
  }

  static void advance(dynamic notifier) {
    final current = notifier.state as TourState;
    notifier.state = current._next();
  }

  static void back(dynamic notifier) {
    final current = notifier.state as TourState;
    if (!current.isActive || current.currentStep == null) return;
    final steps = TourStep.values;
    final idx = steps.indexOf(current.currentStep!);
    if (idx <= 0) return;
    notifier.state = TourState(
      currentStep: steps[idx - 1],
      demoCsvDir: current.demoCsvDir,
      isActive: true,
    );
  }

  /// Cancel the tour: close DB, delete demo files, go back to picker.
  /// Pass [dbPathNotifier] from `ref.read(dbPathProvider.notifier)` to close the DB.
  static void cancel(dynamic notifier, {dynamic dbPathNotifier}) {
    final current = notifier.state as TourState;
    notifier.state = const TourState();
    // Close DB and return to picker
    if (dbPathNotifier != null) dbPathNotifier.state = null;
    _cleanup(current.demoCsvDir);
  }

  /// Complete the tour: delete demo files but keep the DB open.
  static void complete(dynamic notifier) {
    final current = notifier.state as TourState;
    _cleanup(current.demoCsvDir);
    notifier.state = const TourState();
  }

  static void _cleanup(String? demoCsvDir) {
    if (demoCsvDir == null) return;
    try {
      final dir = Directory(demoCsvDir);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        _log.info('Cleaned up tour files at $demoCsvDir');
      }
    } catch (e) {
      _log.warning('Failed to clean up tour files: $e');
    }
  }
}
