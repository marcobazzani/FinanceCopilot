import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/rule_transfer_service.dart';

// The rules export / import messages: counts that read right for one and for
// many in both languages, and the confirmation that says what is replaced.
void main() {
  const en = AppStrings.en;
  const it = AppStrings.it;

  test('export result', () {
    expect(en.rulesExported(1, 1), 'Exported 1 rule and 1 category');
    expect(en.rulesExported(691, 27), 'Exported 691 rules and 27 categories');
    expect(it.rulesExported(1, 1), 'Esportate 1 regola e 1 categoria');
    expect(it.rulesExported(691, 27), 'Esportate 691 regole e 27 categorie');
  });

  test('import confirmation says what is replaced only when there is something to replace', () {
    expect(
      en.importRulesConfirmBody(691, 27, 0),
      'The file holds 691 rules and 27 categories. Categories in the file are added or updated; your other categories stay as they are.',
    );
    expect(en.importRulesConfirmBody(1, 1, 1), startsWith('The file holds 1 rule and 1 category. Your current rule will be replaced.'));
    expect(en.importRulesConfirmBody(2, 3, 12), contains(' Your 12 current rules will be replaced. '));
    expect(
      it.importRulesConfirmBody(691, 27, 0),
      'Il file contiene 691 regole e 27 categorie. Le categorie del file vengono aggiunte o aggiornate; le altre tue categorie restano come sono.',
    );
    expect(it.importRulesConfirmBody(1, 1, 1), startsWith('Il file contiene 1 regola e 1 categoria. La tua regola attuale verrà sostituita.'));
    expect(it.importRulesConfirmBody(2, 3, 12), contains(' Le tue 12 regole attuali verranno sostituite. '));
  });

  test('import result, with the rules left out for a missing account', () {
    expect(en.rulesImported(1, 0), 'Imported 1 rule');
    expect(en.rulesImported(691, 3), 'Imported 691 rules, added 3 categories');
    expect(
      en.rulesImported(5, 1, skipped: 1, missingAccounts: ['Revolut']),
      'Imported 5 rules, added 1 category. 1 rule skipped: account not found (Revolut)',
    );
    expect(en.rulesImported(5, 0, skipped: 3, missingAccounts: ['A', 'B']), 'Imported 5 rules. 3 rules skipped: accounts not found (A, B)');
    expect(it.rulesImported(1, 0), 'Importata 1 regola');
    expect(it.rulesImported(691, 3), 'Importate 691 regole, aggiunte 3 categorie');
    expect(
      it.rulesImported(5, 1, skipped: 1, missingAccounts: ['Revolut']),
      'Importate 5 regole, aggiunta 1 categoria. 1 regola saltata: conto non trovato (Revolut)',
    );
    expect(it.rulesImported(5, 0, skipped: 3, missingAccounts: ['A', 'B']), 'Importate 5 regole. 3 regole saltate: conti non trovati (A, B)');
  });

  test('every reason a file is refused has a message in both languages', () {
    for (final p in RuleFileProblem.values) {
      expect(en.ruleFileProblem(p), isNotEmpty, reason: p.name);
      expect(it.ruleFileProblem(p), isNot(en.ruleFileProblem(p)), reason: p.name);
    }
  });
}
