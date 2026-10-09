// An import issue's text never relies on a field that only some kinds carry:
// a refused replacement whose first replaced day is unknown still reads as a
// refused replacement (it crashed on a null check), in both languages.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });

  const undated = ImportIssue(ImportIssueKind.replaceAborted, 'English log text', rejectedRows: 2, existingRows: 1);

  test('a refused replacement without its first day', () {
    expect(importIssueText(AppStrings.en, undated, locale: 'en_US'), AppStrings.en.importReplaceAbortedUndated(2, 1));
    expect(importIssueText(AppStrings.it, undated, locale: 'it_IT'), AppStrings.it.importReplaceAbortedUndated(2, 1));
  });

  test('pin: with its first day, spelled in the locale', () {
    final dated = ImportIssue(
      ImportIssueKind.replaceAborted,
      'English log text',
      rejectedRows: 2,
      existingRows: 1,
      replaceFrom: DateTime(2026, 1, 20),
    );
    expect(importIssueText(AppStrings.en, dated, locale: 'en_US'), AppStrings.en.importReplaceAborted(2, '1/20/2026', 1));
    expect(importIssueText(AppStrings.it, dated, locale: 'it_IT'), AppStrings.it.importReplaceAborted(2, '20/01/2026', 1));
  });
}
