// Every kind of import issue has its own wording in both languages; the
// refused-replacement date is in the locale's date format.
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

  const it = AppStrings.it;
  const en = AppStrings.en;
  String itText(ImportIssue i) => importIssueText(it, i, locale: 'it_IT');
  String enText(ImportIssue i) => importIssueText(en, i, locale: 'en_US');

  const english = 'English log text';

  test('row issues', () {
    expect(itText(const ImportIssue(ImportIssueKind.emptyDate, english, line: 3)), 'Riga 3: data mancante');
    expect(enText(const ImportIssue(ImportIssueKind.emptyDate, english, line: 3)), 'Line 3: no date');
    expect(itText(const ImportIssue(ImportIssueKind.invalidDate, english, line: 4, value: '31/31/2026')), 'Riga 4: "31/31/2026" non è una data');
    expect(enText(const ImportIssue(ImportIssueKind.invalidDate, english, line: 4, value: '31/31/2026')), 'Line 4: "31/31/2026" is not a date');
    expect(itText(const ImportIssue(ImportIssueKind.emptyAmount, english, line: 5)), 'Riga 5: importo mancante');
    expect(enText(const ImportIssue(ImportIssueKind.emptyAmount, english, line: 5)), 'Line 5: no amount');
    expect(
      itText(const ImportIssue(ImportIssueKind.invalidAmount, english, line: 2, value: 'abc', locale: 'it_IT')),
      'Riga 2: "abc" non è un numero nel formato it_IT',
    );
    expect(
      enText(const ImportIssue(ImportIssueKind.invalidAmount, english, line: 2, value: '-258.35', locale: 'it_IT')),
      'Line 2: "-258.35" is not a number in the it_IT format',
    );
    expect(
      itText(const ImportIssue(ImportIssueKind.untaggedType, english, line: 7, value: 'BONUS')),
      'Riga 7: il tipo "BONUS" non è classificato',
    );
    expect(enText(const ImportIssue(ImportIssueKind.untaggedType, english, line: 7, value: 'BONUS')), 'Line 7: the type "BONUS" is not tagged');
    expect(itText(const ImportIssue(ImportIssueKind.emptyIsin, english, line: 8)), 'Riga 8: ISIN mancante');
    expect(enText(const ImportIssue(ImportIssueKind.emptyIsin, english, line: 8)), 'Line 8: no ISIN');
    expect(
      itText(const ImportIssue(ImportIssueKind.rejected, english, line: 9, fields: ['currency', 'date'])),
      'Riga 9: valore non accettato per Valuta, Data operazione',
    );
    expect(
      enText(const ImportIssue(ImportIssueKind.rejected, english, line: 9, fields: ['currency'])),
      'Line 9: value not accepted for Currency',
    );
    expect(itText(const ImportIssue(ImportIssueKind.other, english, line: 1, value: 'RangeError')), 'Riga 1: RangeError');
    expect(enText(const ImportIssue(ImportIssueKind.other, english, line: 1, value: 'RangeError')), 'Line 1: RangeError');
  });

  test('whole-import issues', () {
    expect(itText(const ImportIssue(ImportIssueKind.dateAndAmountRequired, english)), 'Le colonne data e importo sono obbligatorie');
    expect(enText(const ImportIssue(ImportIssueKind.dateAndAmountRequired, english)), 'The date and amount columns are required');
    expect(itText(const ImportIssue(ImportIssueKind.isinRequired, english)), 'Mappa la colonna ISIN oppure importa in una singola attività');
    expect(enText(const ImportIssue(ImportIssueKind.isinRequired, english)), 'Map the ISIN column, or import into a single asset');
    final aborted = ImportIssue(ImportIssueKind.replaceAborted, english, rejectedRows: 1, existingRows: 4, replaceFrom: DateTime(2026, 1, 20));
    expect(
      itText(aborted),
      'Importazione annullata: 1 riga non può essere salvata, quindi sostituire i movimenti dal 20/01/2026 in poi avrebbe '
      'eliminato 4 movimenti esistenti senza rimpiazzarli. Nulla è stato modificato: correggi la riga indicata sopra e reimporta.',
    );
    expect(
      enText(aborted),
      'Aborted: 1 row could not be stored, so replacing 1/20/2026 onward would have deleted 4 existing transactions '
      'without replacing them. Nothing was changed — fix the row listed above and re-import.',
    );
  });
}
