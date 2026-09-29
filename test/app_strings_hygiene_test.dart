import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

// AppStrings hygiene: members that answered English in both languages, the
// Italian texts that lacked their accents, and the labels that replace enum
// names shown to users.
void main() {
  const it = AppStrings.it;
  const en = AppStrings.en;

  test('members that answered English only have an Italian branch', () {
    expect(it.error('x'), 'Errore: x');
    expect(it.resetZoom, 'Reimposta zoom');
    expect(it.colRate, 'Tasso%');
    expect(it.symbolLabel('VWCE'), 'Simbolo: VWCE');
    expect(it.notApplicable, 'N/D');
    expect(it.notApplicable, it.ratingNa, reason: 'one Italian spelling of "not available"');
    expect(it.sepLabel, 'Separatore:');
  });

  test('their English texts are unchanged', () {
    expect(en.error('x'), 'Error: x');
    expect(en.resetZoom, 'Reset zoom');
    expect(en.colRate, 'Rate%');
    expect(en.symbolLabel('VWCE'), 'Symbol: VWCE');
    expect(en.notApplicable, 'N/A');
    expect(en.sepLabel, 'Sep:');
  });

  test('Italian verbs and nouns carry their accents', () {
    expect(it.importExportBackupConfirmBody(null), startsWith('Il backup attuale su Drive verrà sostituito.'));
    expect(it.importExportRestoreConfirmBody(null), startsWith('Il database locale verrà sostituito'));
    expect(it.landingSubtitle, startsWith('Il tuo database è vuoto.'));
    expect(it.settingsWipeConfirmBody, startsWith('Il database è stato esportato.'));
    expect(it.fieldLabel('quantity'), 'Quantità');
  });

  test('transaction statuses and event types have user-facing names', () {
    expect([for (final t in TransactionStatus.values) it.transactionStatusName(t)], ['In attesa', 'Contabilizzata', 'Annullata']);
    // English keeps the words the status dropdown always showed.
    expect([for (final t in TransactionStatus.values) en.transactionStatusName(t)], ['pending', 'settled', 'cancelled']);
    expect([for (final t in EventType.values) it.eventTypeName(t)], [it.buyLabel, it.sellLabel, it.revalueLabel]);
    expect([for (final t in EventType.values) en.eventTypeName(t)], ['Buy', 'Sell', 'Revalue']);
  });

  test('the FX rate hint shows the example spelled by the caller', () {
    expect(it.rateHint('1,085000'), 'es. 1,085000');
    expect(en.rateHint('1.085000'), 'e.g. 1.085000');
  });
}
