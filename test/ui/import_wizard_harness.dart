// Shared set-up for the import-wizard widget tests: an in-memory database,
// the ImportScreen pumped offline in a chosen language and number locale, and
// an ImportService whose slow steps a test can hold, fail or count.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

class OfflineMarketPriceService extends MarketPriceService {
  OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

/// An [ImportService] whose file reads, dry runs and transaction imports a
/// test can script: hold them on a gate, replace them, and count them.
class ScriptedImportService extends ImportService {
  ScriptedImportService(super.db);

  /// Replaces [parseFile]; receives the path and the rows to skip.
  Future<FilePreview> Function(String path, int skipRows)? onParseFile;

  /// Replaces [getFullRows].
  Future<FilePreview> Function(FilePreview preview)? onGetFullRows;
  int getFullRowsCalls = 0;

  /// Awaited before each dry run (by call index, from 0); may replace it.
  Future<void> Function(int call)? beforePreview;
  Future<TransactionImportPreview> Function(int call)? onPreviewTransactions;
  int previewCalls = 0;

  /// Awaited before the transaction import runs; [onImportTransactions]
  /// replaces it.
  Future<void> Function()? beforeImportTransactions;
  Future<ImportResult> Function()? onImportTransactions;

  @override
  Future<FilePreview> parseFile(String filePath, {String? sheetName, int skipRows = 0, bool noHeader = false, String? numberLocale}) {
    final scripted = onParseFile;
    if (scripted != null) return scripted(filePath, skipRows);
    return super.parseFile(filePath, sheetName: sheetName, skipRows: skipRows, noHeader: noHeader, numberLocale: numberLocale);
  }

  @override
  Future<FilePreview> getFullRows(FilePreview preview, {String? numberLocale}) {
    getFullRowsCalls++;
    final scripted = onGetFullRows;
    if (scripted != null) return scripted(preview);
    return super.getFullRows(preview, numberLocale: numberLocale);
  }

  @override
  Future<TransactionImportPreview> previewTransactionImport({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    required int accountId,
    String balanceMode = 'cumulative',
    String? balanceFilterColumn,
    Set<String>? balanceFilterInclude,
    String? numberLocale,
    String? appLocale,
  }) async {
    final call = previewCalls++;
    await beforePreview?.call(call);
    final scripted = onPreviewTransactions;
    if (scripted != null) return scripted(call);
    return super.previewTransactionImport(
      preview: preview,
      mappings: mappings,
      accountId: accountId,
      balanceMode: balanceMode,
      balanceFilterColumn: balanceFilterColumn,
      balanceFilterInclude: balanceFilterInclude,
      numberLocale: numberLocale,
      appLocale: appLocale,
    );
  }

  @override
  Future<ImportResult> importTransactions({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    required int accountId,
    void Function(int processed, int total)? onProgress,
    String balanceMode = 'cumulative',
    String? balanceFilterColumn,
    Set<String>? balanceFilterInclude,
    String? numberLocaleOverride,
    String? appLocale,
    bool replaceOnlyImportedRows = false,
    Set<String> derivedColumns = const {},
  }) async {
    await beforeImportTransactions?.call();
    final scripted = onImportTransactions;
    if (scripted != null) return scripted();
    return super.importTransactions(
      preview: preview,
      mappings: mappings,
      accountId: accountId,
      onProgress: onProgress,
      balanceMode: balanceMode,
      balanceFilterColumn: balanceFilterColumn,
      balanceFilterInclude: balanceFilterInclude,
      numberLocaleOverride: numberLocaleOverride,
      appLocale: appLocale,
      replaceOnlyImportedRows: replaceOnlyImportedRows,
      derivedColumns: derivedColumns,
    );
  }
}

class ImportHarness {
  late AppDatabase db;
  late ScriptedImportService importer;

  /// Call from `setUp`.
  void open() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ScriptedImportService(db);
  }

  Future<void> close() => db.close();

  static Future<void> initLocales() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  }

  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Pumps [home] (usually an ImportScreen) under [language] strings and the
  /// [locale] number/date format.
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    String language = 'en',
    String locale = 'en_US',
    List<Override> overrides = const [],
    Size size = const Size(1400, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          importServiceProvider.overrideWithValue(importer),
          marketPriceServiceProvider.overrideWithValue(OfflineMarketPriceService(db)),
          privacyModeProvider.overrideWith((ref) => false),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          ...overrides,
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Picks [column] in the mapping dropdown of the field labelled [label].
  Future<void> mapColumn(WidgetTester tester, String label, String column) async {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    final dropdown = find.descendant(of: row, matching: find.byType(DropdownButtonFormField<String>)).first;
    await tester.ensureVisible(dropdown);
    await settle(tester, frames: 4);
    await tester.tap(dropdown);
    await settle(tester, frames: 8);
    await tester.tap(find.text(column).last);
    await settle(tester, frames: 8);
  }
}

/// A gate a scripted step waits on until the test opens it.
class Gate {
  final _completer = Completer<void>();
  Future<void> get wait => _completer.future;
  void open() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
