import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/l10n/app_strings.dart';

// More counts that read right for one and for many, in both languages: these
// members had no singular form, so one wiped event read "Wiped 1 events." and
// one month of FIRE projection "(1 mesi)".
void main() {
  const en = AppStrings.en;
  const it = AppStrings.it;

  test('wiped transactions', () {
    expect(en.wipedTransactions(1), 'Wiped 1 transaction. Import config preserved.');
    expect(en.wipedTransactions(2), 'Wiped 2 transactions. Import config preserved.');
    expect(it.wipedTransactions(1), 'Cancellata 1 transazione. Config. importazione preservata.');
    expect(it.wipedTransactions(2), 'Cancellate 2 transazioni. Config. importazione preservata.');
  });

  test('wiped events', () {
    expect(en.wipedEvents(1), 'Wiped 1 event.');
    expect(en.wipedEvents(2), 'Wiped 2 events.');
    expect(it.wipedEvents(1), 'Cancellato 1 evento.');
    expect(it.wipedEvents(2), 'Cancellati 2 eventi.');
  });

  test('wipe events confirmation', () {
    expect(en.wipeEventsBody(1, 'Fund'), 'This will delete 1 event from "Fund" but keep the asset itself.\n\n');
    expect(en.wipeEventsBody(2, 'Fund'), 'This will delete all 2 events from "Fund" but keep the asset itself.\n\n');
    expect(it.wipeEventsBody(1, 'Fondo'), 'Verrà eliminato 1 evento da "Fondo" ma l\'attività verrà mantenuta.\n\n');
    expect(it.wipeEventsBody(2, 'Fondo'), 'Verranno eliminati tutti i 2 eventi da "Fondo" ma l\'attività verrà mantenuta.\n\n');
  });

  test('restored categories', () {
    expect(en.restoredCategories(1), 'Restored 1 category');
    expect(en.restoredCategories(2), 'Restored 2 categories');
    expect(it.restoredCategories(1), 'Categoria ripristinata: 1');
    expect(it.restoredCategories(2), 'Categorie ripristinate: 2');
  });

  test('delete category confirmation', () {
    expect(
      en.deleteCategoryBody(1, 1),
      'Used by 1 transaction and 1 rule. Pick where to move them, or leave them uncategorized (rules will be deleted).',
    );
    expect(
      en.deleteCategoryBody(2, 2),
      'Used by 2 transactions and 2 rules. Pick where to move them, or leave them uncategorized (rules will be deleted).',
    );
    expect(
      it.deleteCategoryBody(1, 1),
      'Usata da 1 transazione e 1 regola. Scegli dove spostarle, oppure lasciale senza categoria (le regole verranno eliminate).',
    );
    expect(
      it.deleteCategoryBody(2, 2),
      'Usata da 2 transazioni e 2 regole. Scegli dove spostarle, oppure lasciale senza categoria (le regole verranno eliminate).',
    );
    expect(en.deleteCategoryBody(1, 2), startsWith('Used by 1 transaction and 2 rules.'), reason: 'each count on its own');
    expect(it.deleteCategoryBody(2, 1), startsWith('Usata da 2 transazioni e 1 regola.'));
  });

  test('rule matches preview', () {
    expect(en.ruleMatchesPreview(1, 1), 'Matches 1 transaction (1 uncategorized)');
    expect(en.ruleMatchesPreview(2, 2), 'Matches 2 transactions (2 uncategorized)');
    expect(it.ruleMatchesPreview(1, 1), 'Corrisponde a 1 transazione (1 senza categoria)');
    expect(it.ruleMatchesPreview(2, 2), 'Corrisponde a 2 transazioni (2 senza categoria)');
  });

  test('classifier result', () {
    expect(en.classifyResultSnack(1, 2), 'Classified 1 transaction, 2 uncategorized');
    expect(en.classifyResultSnack(2, 1), 'Classified 2 transactions, 1 uncategorized');
    expect(it.classifyResultSnack(1, 2), 'Classificata 1 transazione, 2 senza categoria');
    expect(it.classifyResultSnack(2, 1), 'Classificate 2 transazioni, 1 senza categoria');
  });

  test('wizard rule applied', () {
    expect(en.wizardApplied(1), 'Rule created: 1 transaction classified');
    expect(en.wizardApplied(2), 'Rule created: 2 transactions classified');
    expect(it.wizardApplied(1), 'Regola creata: 1 transazione classificata');
    expect(it.wizardApplied(2), 'Regola creata: 2 transazioni classificate');
  });

  test('spending rows excluded for a missing exchange rate', () {
    expect(en.spendingFxExcluded(1), '1 transaction excluded: exchange rate unavailable');
    expect(en.spendingFxExcluded(2), '2 transactions excluded: exchange rate unavailable');
    expect(it.spendingFxExcluded(1), '1 transazione esclusa: tasso di cambio non disponibile');
    expect(it.spendingFxExcluded(2), '2 transazioni escluse: tasso di cambio non disponibile');
  });

  test('FIRE projection months', () {
    expect(en.fireProjectionMonths(1), '(1m)');
    expect(en.fireProjectionMonths(2), '(2m)');
    expect(it.fireProjectionMonths(1), '(1 mese)');
    expect(it.fireProjectionMonths(2), '(2 mesi)');
  });
}
