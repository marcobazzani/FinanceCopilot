// The portfolio model checks name each problem in a structured form (kind,
// row, what it is about), so the model dialog can show it in the user's
// language instead of the English check text. The English `messages` stay
// word for word; `localizedMessages` words them in the app language, with the
// weights' total in the display locale's decimal separator.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';

void main() {
  PortfolioModelValidationException failure(void Function() check) {
    try {
      check();
    } on PortfolioModelValidationException catch (e) {
      return e;
    }
    fail('the check passed');
  }

  final items = [
    const PortfolioModelInputItem(isin: '', targetWeight: 50),
    const PortfolioModelInputItem(isin: 'IE00B4L5Y98', targetWeight: 0),
    const PortfolioModelInputItem(isin: 'ie00b4l5y983', targetWeight: 30),
    const PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 19.5),
  ];

  test('pinned: the English messages, word for word', () {
    expect(failure(() => PortfolioModelService.validateItems(items)).messages, [
      'row 1: ISIN is required',
      'row 2: ISIN is malformed',
      'row 2: weight must be positive',
      'row 4: duplicate ISIN IE00B4L5Y983',
      'weights must sum to 100% (got 99.50%)',
    ]);
    expect(failure(() => PortfolioModelService.validateItems(items.sublist(1, 2), context: 'Retirement')).messages, [
      'Retirement row 1: ISIN is malformed',
      'Retirement row 1: weight must be positive',
      'weights must sum to 100% (got 0.00%)',
    ]);
    expect(failure(() => PortfolioModelService.validateItems(const [])).messages, [
      'at least one item is required',
      'weights must sum to 100% (got 0.00%)',
    ]);
  });

  test('each problem is named by kind and row', () {
    final issues = failure(() => PortfolioModelService.validateItems(items, context: 'Retirement')).issues;
    expect(
      [for (final i in issues) (i.kind, i.row)],
      [
        (PortfolioModelIssueKind.isinRequired, 1),
        (PortfolioModelIssueKind.isinMalformed, 2),
        (PortfolioModelIssueKind.weightNotPositive, 2),
        (PortfolioModelIssueKind.duplicateIsin, 4),
        (PortfolioModelIssueKind.weightsTotal, null),
      ],
    );
    expect(issues[3].value, 'IE00B4L5Y983');
    expect(issues.last.total, 99.5);
    expect(issues.first.context, 'Retirement');
  });

  test('in Italian, with the Italian decimal comma', () {
    expect(failure(() => PortfolioModelService.validateItems(items)).localizedMessages(AppStrings.it, locale: 'it_IT'), [
      'riga 1: l\'ISIN è obbligatorio',
      'riga 2: ISIN non valido',
      'riga 2: il peso deve essere positivo',
      'riga 4: ISIN IE00B4L5Y983 duplicato',
      'i pesi devono sommare al 100% (totale 99,50%)',
    ]);
    expect(failure(() => PortfolioModelService.validateItems(const [])).localizedMessages(AppStrings.it, locale: 'it_IT'), [
      'serve almeno una riga',
      'i pesi devono sommare al 100% (totale 0,00%)',
    ]);
    expect(
      failure(
        () => PortfolioModelService.validateItems(items.sublist(0, 1), context: 'Pensione'),
      ).localizedMessages(AppStrings.it, locale: 'it_IT'),
      ['Pensione riga 1: l\'ISIN è obbligatorio', 'i pesi devono sommare al 100% (totale 50,00%)'],
    );
  });

  test('in English, the English messages; the total in the display locale', () {
    final e = failure(() => PortfolioModelService.validateItems(items));
    expect(e.localizedMessages(AppStrings.en, locale: 'en_US'), e.messages);
    expect(e.localizedMessages(AppStrings.en, locale: 'it_IT').last, 'weights must sum to 100% (got 99,50%)');
  });

  test('a model without a name, and a catalog file without an ID or with an unreadable weight', () async {
    final noName = failure(() => PortfolioModelService.parseMarkdown('# Model\n\n| ISIN | Weight | Name |\n|---|---|---|\n'));
    expect(noName.issues.single.kind, PortfolioModelIssueKind.missingId);
    expect(noName.messages, ['missing model ID']);
    expect(noName.localizedMessages(AppStrings.it, locale: 'it_IT'), ['ID del modello mancante']);

    final inFile = failure(() => PortfolioModelService.parseMarkdown('# Model\n', path: 'PortfolioModels/a.md'));
    expect(inFile.messages, ['missing model ID in PortfolioModels/a.md']);
    expect(inFile.localizedMessages(AppStrings.it, locale: 'it_IT'), ['ID del modello mancante in PortfolioModels/a.md']);

    final badWeight = failure(
      () =>
          PortfolioModelService.parseMarkdown('# Model\nID: `m1`\n\n| ISIN | Weight | Name |\n|---|---|---|\n| IE00B4L5Y983 | lots | World |\n'),
    );
    expect(badWeight.messages, ['invalid weight "lots" in m1']);
    expect(badWeight.localizedMessages(AppStrings.it, locale: 'it_IT'), ['peso "lots" non valido in m1']);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final service = PortfolioModelService(db);
    await expectLater(
      service.createCustomModel(name: '  ', items: const []),
      throwsA(
        isA<PortfolioModelValidationException>().having((e) => e.messages, 'messages', ['name is required']).having(
          (e) => e.localizedMessages(AppStrings.it, locale: 'it_IT'),
          'in Italian',
          ['il nome è obbligatorio'],
        ),
      ),
    );
  });
}
