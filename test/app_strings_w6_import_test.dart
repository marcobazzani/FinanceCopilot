import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

// Counts of the import wizard, the selection bar and the classification
// wizard read right for one and for many, in both languages — "1 rows
// hidden", "1 righe non possono essere salvate" and "1 selezionati" were what
// a count concatenated with a plural noun produced. And Italian texts that
// were half English or misspelled.
void main() {
  const en = AppStrings.en;
  const it = AppStrings.it;

  group('counts', () {
    test('selection', () {
      expect(en.nSelected(1), '1 selected');
      expect(en.nSelected(2), '2 selected');
      expect(it.nSelected(1), '1 selezionato');
      expect(it.nSelected(2), '2 selezionati');
    });

    test('classification wizard: entries without an exchange rate', () {
      expect(en.wizardFxExcludedNote(1), '1 entry without an exchange rate: excluded from the amounts');
      expect(en.wizardFxExcludedNote(2), '2 entries without an exchange rate: excluded from the amounts');
      expect(it.wizardFxExcludedNote(1), '1 movimento senza tasso di cambio: escluso dagli importi');
      expect(it.wizardFxExcludedNote(2), '2 movimenti senza tasso di cambio: esclusi dagli importi');
    });

    test('classification wizard: entries that do not take part', () {
      expect(en.wizardExcludedNote(1), '1 entry does not take part: transfers, no-ops, adjustments and cancelled');
      expect(en.wizardExcludedNote(2), '2 entries do not take part: transfers, no-ops, adjustments and cancelled');
      expect(it.wizardExcludedNote(1), '1 movimento non partecipa: trasferimenti, storni, rettifiche e annullati');
      expect(it.wizardExcludedNote(2), '2 movimenti non partecipano: trasferimenti, storni, rettifiche e annullati');
    });

    test('refused replacement', () {
      expect(
        en.importReplaceAborted(1, '1/20/2026', 1),
        'Aborted: 1 row could not be stored, so replacing 1/20/2026 onward would have deleted 1 existing transaction without replacing it. '
        'Nothing was changed — fix the row listed above and re-import.',
      );
      expect(
        en.importReplaceAborted(2, '1/20/2026', 2),
        'Aborted: 2 rows could not be stored, so replacing 1/20/2026 onward would have deleted 2 existing transactions without replacing them. '
        'Nothing was changed — fix the rows listed above and re-import.',
      );
      expect(
        it.importReplaceAborted(1, '20/01/2026', 1),
        'Importazione annullata: 1 riga non può essere salvata, quindi sostituire i movimenti dal 20/01/2026 in poi avrebbe eliminato '
        '1 movimento esistente senza rimpiazzarlo. Nulla è stato modificato: correggi la riga indicata sopra e reimporta.',
      );
      expect(
        it.importReplaceAborted(2, '20/01/2026', 2),
        'Importazione annullata: 2 righe non possono essere salvate, quindi sostituire i movimenti dal 20/01/2026 in poi avrebbe eliminato '
        '2 movimenti esistenti senza rimpiazzarli. Nulla è stato modificato: correggi le righe indicate sopra e reimporta.',
      );
      expect(en.importReplaceAborted(1, '1/20/2026', 4), contains('1 row could not be stored'), reason: 'each count on its own');
      expect(en.importReplaceAborted(1, '1/20/2026', 4), contains('deleted 4 existing transactions without replacing them'));
    });

    test('refused replacement without its first day', () {
      expect(
        en.importReplaceAbortedUndated(1, 1),
        'Aborted: 1 row could not be stored, so the replacement would have deleted 1 existing transaction without replacing it. '
        'Nothing was changed — fix the row listed above and re-import.',
      );
      expect(
        it.importReplaceAbortedUndated(2, 3),
        'Importazione annullata: 2 righe non possono essere salvate, quindi la sostituzione avrebbe eliminato '
        '3 movimenti esistenti senza rimpiazzarli. Nulla è stato modificato: correggi le righe indicate sopra e reimporta.',
      );
    });

    test('income entries added from a split', () {
      expect(en.incomeFlaggedSplitSnack(1), 'Added 1 income entry');
      expect(en.incomeFlaggedSplitSnack(2), 'Added 2 income entries');
      expect(it.incomeFlaggedSplitSnack(1), 'Aggiunta 1 voce di reddito');
      expect(it.incomeFlaggedSplitSnack(2), 'Aggiunte 2 voci di reddito');
    });

    test('re-run banner', () {
      expect(en.rerunImportBanner(1), 'Re-running 1 transaction from stored data: no file needed, manually entered rows are kept.');
      expect(en.rerunImportBanner(2), 'Re-running 2 transactions from stored data: no file needed, manually entered rows are kept.');
      expect(
        it.rerunImportBanner(1),
        'Rielaborazione di 1 transazione dai dati salvati: nessun file necessario, le righe inserite a mano restano intatte.',
      );
      expect(
        it.rerunImportBanner(2),
        'Rielaborazione di 2 transazioni dai dati salvati: nessun file necessario, le righe inserite a mano restano intatte.',
      );
    });

    test('mapper title', () {
      expect(en.mapColumnsTitle(1, 1), 'Map columns (1 column, 1 row)');
      expect(en.mapColumnsTitle(2, 2), 'Map columns (2 columns, 2 rows)');
      expect(en.mapColumnsTitle(1, 2), 'Map columns (1 column, 2 rows)', reason: 'each count on its own');
      expect(it.mapColumnsTitle(1, 1), 'Mappa colonne (1 colonna, 1 riga)');
      expect(it.mapColumnsTitle(2, 2), 'Mappa colonne (2 colonne, 2 righe)');
      expect(it.mapColumnsTitle(2, 1), 'Mappa colonne (2 colonne, 1 riga)');
    });

    test('preview rows', () {
      expect(en.previewRows(1), 'Preview (1 row)');
      expect(en.previewRows(2), 'Preview (2 rows)');
      expect(it.previewRows(1), 'Anteprima (1 riga)');
      expect(it.previewRows(2), 'Anteprima (2 righe)');
    });

    test('hidden rows', () {
      expect(en.hiddenRows(1), '⋯ 1 row hidden ⋯');
      expect(en.hiddenRows(2), '⋯ 2 rows hidden ⋯');
      expect(it.hiddenRows(1), '⋯ 1 riga nascosta ⋯');
      expect(it.hiddenRows(2), '⋯ 2 righe nascoste ⋯');
    });

    test('file empty after skipping rows', () {
      expect(en.fileEmptyAfterSkip(1), 'File is empty after skipping 1 row.');
      expect(en.fileEmptyAfterSkip(2), 'File is empty after skipping 2 rows.');
      expect(it.fileEmptyAfterSkip(1), 'Il file è vuoto dopo aver saltato 1 riga.');
      expect(it.fileEmptyAfterSkip(2), 'Il file è vuoto dopo aver saltato 2 righe.');
    });
  });

  group('Italian texts', () {
    test('units in other pillars', () {
      expect(it.pillarMaxPercentElsewhere(97, '3'), 'max 97% · 3 unità in altri pilastri');
      expect(en.pillarMaxPercentElsewhere(97, '3'), 'max 97% · 3 units in other pillars');
    });

    test('income-to-wealth KPI', () {
      expect(it.kpiIncomeToWealth, 'Tasso di sproporzione entrate/patrimonio');
      expect(en.kpiIncomeToWealth, 'Income-to-Wealth Ratio');
    });

    test('an ephemeral event names the Cash and Saving charts as they are called', () {
      expect(it.eventEphemeralHelp, 'Soldi che non hai ma puoi spendere: contribuiscono alla Liquidità ma non ai Risparmi.');
      for (final s in [it, en]) {
        expect(s.eventEphemeralHelp, contains(s.dashCash));
        expect(s.eventEphemeralHelp, contains(s.dashSaving));
      }
    });

    test('auto-calculation toggles', () {
      expect(it.autoCalc, 'Calcolo automatico');
      expect(it.autoCalcFromAmount, 'Calcolo automatico da importo');
      expect(en.autoCalc, 'Auto calc');
      expect(en.autoCalcFromAmount, 'Auto calc from amount');
    });

    test('crypto', () {
      expect(it.assetTypeLabel(AssetType.crypto), 'Cripto');
      expect(it.instrumentTypeLabel(InstrumentType.crypto), 'Cripto');
      expect(it.assetClassLabel(AssetClass.crypto), 'Cripto');
      expect(en.assetTypeLabel(AssetType.crypto), 'Crypto');
      expect(en.instrumentTypeLabel(InstrumentType.crypto), 'Crypto');
      expect(en.assetClassLabel(AssetClass.crypto), 'Crypto');
    });

    test('year over year row', () {
      expect(it.yoyRowLabel, 'A/A');
      expect(en.yoyRowLabel, 'YoY');
    });

    test('concentration of the largest holdings', () {
      expect([it.top1, it.top3, it.top5], ['Prima posizione', 'Prime 3 posizioni', 'Prime 5 posizioni']);
      expect([en.top1, en.top3, en.top5], ['Top 1', 'Top 3', 'Top 5']);
    });
  });
}
