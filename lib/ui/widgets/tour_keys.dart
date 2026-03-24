import 'package:flutter/widgets.dart';

/// GlobalKey registry for the guided tour spotlight targets.
class TourKeys {
  TourKeys._();

  // DbPicker screen
  static final newProjectButton = GlobalKey(debugLabel: 'tour_newProject');

  // Navigation rail destinations
  static final navAccounts = GlobalKey(debugLabel: 'tour_navAccounts');
  static final navAssets = GlobalKey(debugLabel: 'tour_navAssets');
  static final navAdjustments = GlobalKey(debugLabel: 'tour_navAdjustments');
  static final navIncome = GlobalKey(debugLabel: 'tour_navIncome');

  // Screen FABs
  static final accountsImportFab = GlobalKey(debugLabel: 'tour_accountsImportFab');
  static final assetsImportFab = GlobalKey(debugLabel: 'tour_assetsImportFab');
  static final adjustmentsFab = GlobalKey(debugLabel: 'tour_adjustmentsFab');
  static final incomeImportFab = GlobalKey(debugLabel: 'tour_incomeImportFab');

  // Import screen buttons
  static final importOpenFile = GlobalKey(debugLabel: 'tour_importOpenFile');
  static final importSkipRows = GlobalKey(debugLabel: 'tour_importSkipRows');
  static final importMapDate = GlobalKey(debugLabel: 'tour_importMapDate');
  static final importMapAmount = GlobalKey(debugLabel: 'tour_importMapAmount');
  static final importFormula = GlobalKey(debugLabel: 'tour_importFormula');
  static final importMapDescription = GlobalKey(debugLabel: 'tour_importMapDescription');
  static final importBalance = GlobalKey(debugLabel: 'tour_importBalance');
  static final importDedup = GlobalKey(debugLabel: 'tour_importDedup');
  static final importNext = GlobalKey(debugLabel: 'tour_importNext');
  static final importConfirm = GlobalKey(debugLabel: 'tour_importConfirm');
  static final importDone = GlobalKey(debugLabel: 'tour_importDone');
}
