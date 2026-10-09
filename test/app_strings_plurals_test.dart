import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/l10n/app_strings.dart';

// Counts read right for one and for many, in both languages: "1 transactions"
// or "Ricalcolati 1 saldi." were what a count concatenated with a plural noun,
// or a member with no singular form, produced.
void main() {
  const en = AppStrings.en;
  const it = AppStrings.it;

  test('transaction count', () {
    expect(en.transactionCount(1), '1 transaction');
    expect(en.transactionCount(2), '2 transactions');
    expect(it.transactionCount(1), '1 transazione');
    expect(it.transactionCount(2), '2 transazioni');
  });

  test('record count', () {
    expect(en.recordCount(1), '1 record');
    expect(en.recordCount(2), '2 records');
    expect(it.recordCount(1), '1 record');
    expect(it.recordCount(2), '2 record');
  });

  test('event count', () {
    expect(en.nEvents(1), '1 event');
    expect(en.nEvents(2), '2 events');
    expect(it.nEvents(1), '1 evento');
    expect(it.nEvents(2), '2 eventi');
  });

  test('recalculated balances', () {
    expect(en.recalculatedBalances(1), 'Recalculated 1 balance.');
    expect(en.recalculatedBalances(2), 'Recalculated 2 balances.');
    expect(it.recalculatedBalances(1), 'Ricalcolato 1 saldo.');
    expect(it.recalculatedBalances(2), 'Ricalcolati 2 saldi.');
  });

  test('bulk delete confirmation', () {
    expect(en.bulkDeleteBody(1), '1 item will be permanently deleted. This cannot be undone.');
    expect(en.bulkDeleteBody(2), '2 items will be permanently deleted. This cannot be undone.');
    expect(it.bulkDeleteBody(1), 'Verrà eliminato 1 elemento. Operazione irreversibile.');
    expect(it.bulkDeleteBody(2), 'Verranno eliminati 2 elementi. Operazione irreversibile.');
  });

  test('category set on transactions', () {
    expect(en.setCategoryCount(1), 'Category set on 1 transaction');
    expect(en.setCategoryCount(2), 'Category set on 2 transactions');
    expect(it.setCategoryCount(1), 'Categoria impostata su 1 transazione');
    expect(it.setCategoryCount(2), 'Categoria impostata su 2 transazioni');
  });

  test('spread preview', () {
    expect(en.spreadPreview(1, '€ 100'), '1 step × € 100');
    expect(en.spreadPreview(2, '€ 100'), '2 steps × € 100');
    expect(it.spreadPreview(1, '€ 100'), '1 passo × € 100');
    expect(it.spreadPreview(2, '€ 100'), '2 passi × € 100');
  });

  test('expense coverage description', () {
    expect(en.kpiCoverageDesc(1), 'Your cash covers your expenses for 1 month.');
    expect(en.kpiCoverageDesc(2), 'Your cash covers your expenses for 2 months.');
    expect(it.kpiCoverageDesc(1), 'La tua liquidità copre le tue spese per 1 mese.');
    expect(it.kpiCoverageDesc(2), 'La tua liquidità copre le tue spese per 2 mesi.');
  });
}
