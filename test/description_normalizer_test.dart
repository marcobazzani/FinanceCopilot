import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/description_normalizer.dart';
import 'package:finance_copilot/services/classification/normalizer/entry_kind_lexicon.dart';
import 'package:finance_copilot/services/classification/normalizer/statement_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

NormalizedEntry n(String d, {bool inflow = false, String? full, Map<String, dynamic>? meta}) =>
    normalizeDescription(description: d, descriptionFull: full, rawMetadata: meta, inflow: inflow);

void main() {
  group('card slips (`<causale> - <merchant> Carta N. ... Data operazione ...`)', () {
    test('same merchant on different dates and cards → same key', () {
      final a = n('Pagamento Visa Debit - Acme**5591* Dublin IE Carta N. ***** 172 Data operazione 02/12/24');
      final b = n('Pagamento Visa Debit - Acme**7166* Dublin IE Carta N. ***** 172 Data operazione 19/04/23');
      expect(a.merchantKey, 'ACMEDUBLIN');
      expect(b.merchantKey, a.merchantKey);
      expect(a.entryKind, BankEntryKind.cardPayment);
      expect(a.counterparty, 'Acme Dublin');
    });

    test('card slip with `C/O` merchant, time and mask', () {
      final e = n('PAGAMENTO TRAMITE POS POS CARTA EASYPLUS N. ****2569 DEL 24/03/22 ORE 19:29 C/O Bakery**1383* Vilnius LTU');
      expect(e.merchantKey, 'BAKERYVILNIUS');
      expect(e.counterparty, 'Bakery Vilnius');
      expect(e.entryKind, BankEntryKind.cardPayment);
    });

    test('bare `VISA DEBIT - Merchant**1234*`', () {
      expect(n('VISA DEBIT - Acme**7166*').merchantKey, 'ACME');
    });
  });

  group('SEPA payer/payee formats', () {
    const inbound =
        'Bonifico SEPA Italia - Ord: Generic Insurer S.p.A. Ben: JOHN DOE Dt-ord: 21/05/2024 Banca Ord: UNI CREDIT SPA Info-Cli: DMALOBSA-DAN:033-20 24-000228904,POL:334662015JOHN DOE';

    test('inflow uses the payer (Ord), outflow uses the payee (Ben)', () {
      expect(n(inbound, inflow: true).merchantKey, 'GENERICINSURERSPA');
      expect(n(inbound, inflow: true).counterparty, 'Generic Insurer S.p.A.');
      expect(n(inbound, inflow: false).merchantKey, 'JOHNDOE');
      expect(n(inbound).entryKind, BankEntryKind.transfer);
    });

    test('salary head overrides transfer kind, counterparty still the payer', () {
      final e = n(
        'Stipendio - Ord: Generic Insurer S.p.A. Ben: JOHN DOE Dt-ord: 31/12/2024 Banca Ord: UNI CREDIT SPA Info-Cli: PAGAMENTO MESE:1220 24JOHN DOE',
        inflow: true,
      );
      expect(e.entryKind, BankEntryKind.salary);
      expect(e.merchantKey, 'GENERICINSURERSPA');
    });

    test('PDF column-wrap artifacts inside names collapse in the key', () {
      final a = n('Bonifico SEPA Estero - Ord: MR. JOHN DOE Ben: JOHN DO E BROKER Dt-ord: 21/04/2022 Banca Ord: K BC BANK', inflow: true);
      final b = n(
        'Bonifico Istantaneo - Ordinante: John Doe Beneficiario: J ohn Doe Banca Ordinante: PAY MENTS UAB Data accredito: 27/07/2022 Ca usale: Benzina',
        inflow: true,
      );
      expect(a.merchantKey, 'MRJOHNDOE');
      expect(b.merchantKey, 'JOHNDOE');
    });

    test('`ORD:<payer> DT.ORD:` credit format', () {
      final e = n(
        'ACCREDITO EMOLUMENTI ORD:GENERIC BUSINESS SOLUTIONSS.C.P.A. DT.ORD:000000 DESCR.OPERAZIONE SCT:PAGAMENTO MESE:062021JOHN DOE<*> RIFERIMENTO SCT:2021060400500066970097 STIPENDIO IDENTIFICATIVO SCT',
        inflow: true,
        meta: {'Causale': 'ACCREDITO EMOLUMENTI'},
      );
      expect(e.entryKind, BankEntryKind.salary);
      expect(e.merchantKey, 'GENERICBUSINESSSOLUTIONSSCPA');
    });

    test('`DISPOSIZIONE DI PAGAMENTO` picks the payee and drops references', () {
      final a = n(
        'DISPOSIZIONE DI PAGAMENTO 00760 JOHN DOE 000000324647100 JOHN DOE V/ORDINE ECONTO DESCR.OPERAZIONE:SCT ISTANTANEO DEL 31/08/2022 ORE 07:39<*> IDENTIFICATIVO SCT:0623096680424302480010070604IT',
      );
      final b = n(
        'DISPOSIZIONE DI PAGAMENTO 00760 JOHN DOE 000000295633673 JOHN DOE V/ORDINE ECONTO IDENTIFICATIVO SCT:0623063747512312489999970604IT',
      );
      expect(a.merchantKey, 'JOHNDOE');
      expect(b.merchantKey, 'JOHNDOE');
      expect(a.entryKind, BankEntryKind.transfer);
    });

    test('`GIROCONTO/BONIFICO ORD:` with IBAN and reference', () {
      final e = n(
        'GIROCONTO/BONIFICO ORD:JOHN DOE DT.ORD:200821 DESCR.OPERAZIONE SCT:INVIATODA X-SCT ISTANT ANEO DEL 20/08/2021 ORE 13:11<*> IDENTIFICATIVO SCT:XYZ21082066386339126 IBAN:LT36325005326346',
        inflow: true,
      );
      expect(e.merchantKey, 'JOHNDOE');
    });
  });

  group('prefixed formats (POS / C-POS / SDD / SCT / STO / ATM)', () {
    test('POS merchant + trailing yyyymmdd', () {
      expect(n('POS THE GARDEN TERRACE B 20180720').merchantKey, 'THEGARDENTERRACEB');
      expect(n('POS THE GARDEN TERRACE B 20190101').merchantKey, 'THEGARDENTERRACEB');
      expect(n('C-POS EUROSPAR MILLTOWN 20170911').merchantKey, 'EUROSPARMILLTOWN');
      expect(n('POS SPAR 20170429').entryKind, BankEntryKind.cardPayment);
    });

    test('merchant with attached reference digits', () {
      expect(n('POS Acme1946 20210514').merchantKey, 'ACME');
      expect(n('POS Acme1512 20191109').merchantKey, 'ACME');
    });

    test('trailing punctuation dash date', () {
      expect(n('POS ASPI VILLANOVA B. - 20200110').merchantKey, 'ASPIVILLANOVAB');
    });

    test('SDD / SCT / MOBILE SCT / STO', () {
      final sdd = n('SDD Virgin Media Ireland Limited');
      expect(sdd.entryKind, BankEntryKind.directDebit);
      expect(sdd.merchantKey, 'VIRGINMEDIAIRELANDLIMITED');
      final sct = n('SCT JOHN DOE NOT PROVIDED', inflow: true);
      expect(sct.entryKind, BankEntryKind.transfer);
      expect(sct.merchantKey, 'JOHNDOE');
      expect(n('MOBILE SCT John Doe Broker').merchantKey, 'JOHNDOEBROKER');
      expect(n('STO Landlord Ltd').entryKind, BankEntryKind.standingOrder);
    });

    test('fee lines keep their whole text as key', () {
      final e = n('Non-Euro Point Of Sales Fee');
      expect(e.entryKind, BankEntryKind.fee);
      expect(e.merchantKey, 'NONEUROPOINTOFSALESFEE');
    });
  });

  group('app-bank exports (type column + plain merchant)', () {
    test('type hint from metadata drives the kind', () {
      expect(n('Trenitalia Spa', meta: {'Tipo': 'Pagamento con carta'}).entryKind, BankEntryKind.cardPayment);
      expect(n('To HERA S.P.A.', meta: {'Tipo': 'Pagamento'}).entryKind, BankEntryKind.transfer);
      expect(n('Prelievo di contanti presso Banca Pop Em', meta: {'Tipo': 'Prelievo'}).entryKind, BankEntryKind.atmWithdrawal);
      expect(n('Acme', meta: {'Tipo': 'Rimborso su carta'}).entryKind, BankEntryKind.refund);
      expect(n('Acme', meta: {'Tipo': 'Chargeback su carta'}).entryKind, BankEntryKind.refund);
      expect(n('EUR → USD', meta: {'Tipo': 'Cambia valuta'}).entryKind, BankEntryKind.fxExchange);
      expect(n('Acme', meta: {'Tipo': 'Commissione'}).entryKind, BankEntryKind.fee);
      expect(n('Acme', meta: {'Tipo': 'Ricompensa'}).entryKind, BankEntryKind.refund);
    });

    test('`To X` / `Pagamento da parte di X` strip the prefix; case-insensitive key', () {
      expect(n('To HERA S.P.A.').merchantKey, 'HERASPA');
      expect(n('To Hera S.p.a.').merchantKey, 'HERASPA');
      expect(n('Pagamento da parte di JOHN DOE', inflow: true).merchantKey, 'JOHNDOE');
      expect(n('Pagamento a favore di JOHN DOE').merchantKey, 'JOHNDOE');
      expect(n('To Hera S.p.a.').counterparty, 'Hera S.p.a.');
    });

    test('card top-ups group per card mask', () {
      final a = n('Ricarica di *1172', inflow: true, meta: {'Tipo': 'Ricarica'});
      final b = n('Ricarica di *1172', inflow: true, meta: {'Tipo': 'Ricarica'});
      final c = n('Ricarica di *3710', inflow: true, meta: {'Tipo': 'Ricarica'});
      expect(a.entryKind, BankEntryKind.cardTopUp);
      expect(a.merchantKey, 'TOPUP*1172');
      expect(b.merchantKey, a.merchantKey);
      expect(c.merchantKey, 'TOPUP*3710');
      expect(a.counterparty, '*1172');
    });

    test('plain merchant names', () {
      expect(n("Autostrade per l'Italia").merchantKey, 'AUTOSTRADEPERLITALIA');
      expect(n('Pizzikotto Vignola').merchantKey, 'PIZZIKOTTOVIGNOLA');
      expect(n('Tubooza Cafe?').merchantKey, 'TUBOOZACAFE');
      expect(n('Accredita EUR Salve Danaio da EUR').entryKind, BankEntryKind.transfer);
      expect(n('Prelievo da Pocket').entryKind, BankEntryKind.transfer);
    });
  });

  group('kind detection from the description head', () {
    test('tax beats securities in `Imposta bollo dossier titoli`', () {
      expect(n('Imposta bollo dossier titoli - Imposta bollo dossier titoli').entryKind, BankEntryKind.tax);
      expect(n('IMPOSTE E TASSE', meta: {'Causale': 'IMPOSTE E TASSE'}).entryKind, BankEntryKind.tax);
      expect(n('Government Stamp Duty').entryKind, BankEntryKind.tax);
    });

    test('securities trades group by instrument, quantity dropped', () {
      final a = n('Compravendita Titoli - Compravendita Titoli ISHS CR WD USD-AC Qta/Val.nom. 27,000000');
      final b = n('Compravendita Titoli - Compravendita Titoli ISHS CR WD USD-AC Qta/Val.nom. 120,000000');
      expect(a.entryKind, BankEntryKind.securitiesTrade);
      expect(a.merchantKey, 'COMPRAVENDITATITOLIISHSCRWDUSDAC');
      expect(b.merchantKey, a.merchantKey);
    });

    test('monthly fee/refund lines are stable across months', () {
      final a = n('Sconto Canone Mensile - Sconto Canone Mensile Aprile 2024', inflow: true);
      final b = n('Sconto Canone Mensile - Sconto Canone Mensile Maggio 2022', inflow: true);
      expect(a.entryKind, BankEntryKind.refund);
      expect(a.merchantKey, 'SCONTOCANONEMENSILE');
      expect(b.merchantKey, a.merchantKey);
      expect(n('Canone Mensile Conto - Canone Mensile Conto Marzo 2023').entryKind, BankEntryKind.fee);
    });

    test('other heads', () {
      expect(n('Prelievo Bancomat - Prelievo Bancomat Carta N. ***** 172 Data operazione 10/12/22').entryKind, BankEntryKind.atmWithdrawal);
      expect(n('Cambio valuta - EUR/USD').entryKind, BankEntryKind.fxExchange);
      expect(n('Ricarica telefonica - Ricarica telefonica Acme 3xx').entryKind, BankEntryKind.cardPayment);
      expect(n('Versamento Contanti presso ATM - ...', inflow: true).entryKind, BankEntryKind.cashDeposit);
      expect(n('SEPA Direct Debit - Ord: X Ben: Y').entryKind, BankEntryKind.directDebit);
      expect(n('Interest', inflow: true).entryKind, BankEntryKind.interest);
      expect(n('Random text').entryKind, BankEntryKind.unknown);
    });
  });

  group('robustness', () {
    test('empty description falls back to a kind key', () {
      final e = n('');
      expect(e.merchantKey, 'UNKNOWN');
      expect(e.counterparty, isNull);
    });

    test('pure-noise description falls back to a kind key', () {
      final e = n('12/03/2024 15:30 0000123456', meta: {'Tipo': 'Commissione'});
      expect(e.merchantKey, 'FEE');
    });

    test('full description is appended only when not already contained', () {
      final a = n('Acme', full: 'Acme');
      final b = n('Acme', full: 'Acme Store Rome');
      expect(a.merchantKey, 'ACME');
      expect(b.merchantKey, 'ACMEACMESTOREROME');
    });

    test('key is capped at 32 chars, counterparty at 60', () {
      final e = n('A very long merchant name that goes on and on and on and on forever and ever');
      expect(e.merchantKey.length, 32);
      expect(e.counterparty!.length, lessThanOrEqualTo(60));
    });

    test('whitespace-insensitive', () {
      expect(n('  POS   SPAR   20170429 ').merchantKey, 'SPAR');
    });
  });

  group('payee-only transfer formats', () {
    test('`Ben: X Ins: <date time> Da: INTERNET Iban: …` yields the payee', () {
      final e = n(
        'Bonifico SEPA Italia - Ben: GRUPPO HERA Ins: 02/01/2025 15:13:3 7 Da: INTERNET Iban: IT91M0200809292 TransID: 123 Cau: bolletta',
      );
      expect(e.merchantKey, 'GRUPPOHERA');
      expect(e.counterparty, 'GRUPPO HERA');
      expect(e.format, 'payeeOnly');
      expect(
        n('Bonifico SEPA Italia - Ben: SERRA BETON S.R.L. Ins: 20/04/2026 19:10:16 Da: INTERNET Iban: IT61O0503').counterparty,
        'SERRA BETON S.R.L.',
      );
    });

    test('`Beneficiario: X IBAN: … Data Inserimento: …`, including a wrapped `IBA N`', () {
      expect(
        n(
          'Bonifico Istantaneo - Beneficiario: Ensama srl IBAN: IT06C0303 236650010000576153 Data Inserimento: 10/01/2025 Canale: APP',
        ).merchantKey,
        'ENSAMASRL',
      );
      expect(
        n(
          'Bonifico Istantaneo - Beneficiario: Sporting Hotel Ravelli IBA N: IT17V0816335010000190116272 Data I nserimento: 1/2/2025',
        ).merchantKey,
        'SPORTINGHOTELRAVELLI',
      );
    });

    test('payer/payee pair still wins over payee-only when both markers exist', () {
      expect(n('Bonifico - Ord: ALICE Ben: BOB Dt-ord: 1/1/24', inflow: true).merchantKey, 'ALICE');
      expect(n('Bonifico - Ord: ALICE Ben: BOB Dt-ord: 1/1/24').format, 'payerPayee');
    });
  });

  group('kind vocabulary is anchored where a merchant name could contain it', () {
    test('a POS purchase of phone credit is a card payment, not a card top-up', () {
      expect(n('POS VODAFONE TOP UP VEST 20170302').entryKind, BankEntryKind.cardPayment);
      expect(n('Top-Up by card', meta: {'Type': 'Top-Up'}).entryKind, BankEntryKind.cardTopUp);
    });
  });

  group('statement tokens', () {
    test('segmentLine alternates word/non-word runs and round-trips', () {
      const line = 'POS Acme**12* 20180720, IE';
      final segs = segmentLine(line);
      expect(segs.map((s) => s.text).join(), line);
      expect(segs.map((s) => s.isWord).toList(), [true, false, true, false, true, false, true]);
    });

    test('stripCardMask keeps the halves of a masked name as two words', () {
      expect(stripCardMask('Revolut**5591*'), 'Revolut');
      expect(stripCardMask('****2569'), '');
      expect(stripCardMask('Amz*wp'), 'Amz wp');
      expect(stripCardMask('M**Bun'), 'M Bun');
    });

    test('trimGluedStoreNumber only trims ≥3 trailing digits after a letter', () {
      expect(trimGluedStoreNumber('Acme1946'), 'Acme');
      expect(trimGluedStoreNumber('H24'), 'H24');
      expect(trimGluedStoreNumber('7Eleven'), '7Eleven');
      expect(trimGluedStoreNumber('20180720'), '20180720');
    });

    test('date/time sequences are removed with their DEL/ORE introducers, seconds included', () {
      expect(stripStatementNoise('Bar DEL 24/03/22 ORE 19:29 Roma'), 'Bar Roma');
      expect(stripStatementNoise('Atm del 14/01/2023 ore 11:29:39 Rif.'), 'Atm Rif.');
      expect(stripStatementNoise('Shop 2024-03-24 x'), 'Shop x');
      expect(stripStatementNoise('Data: 20 /01/23 Ora: 18:40'), 'Data: Ora');
    });

    test('trailing sections, months, NOT PROVIDED, N. + mask, country codes', () {
      expect(stripStatementNoise('Acme Carta N. ***** 172 Data operazione 02/12/24'), 'Acme');
      expect(stripStatementNoise('Canone Aprile 2024'), 'Canone');
      expect(stripStatementNoise('JOHN DOE NOT PROVIDED'), 'JOHN DOE');
      expect(stripStatementNoise('Prelevamento carta N ***** 117'), 'Prelevamento carta');
      expect(stripStatementNoise('Acme Dublin IE'), 'Acme Dublin');
      expect(stripStatementNoise('Trenitalia Spa'), 'Trenitalia Spa', reason: 'only upper-case codes are country codes');
      expect(stripStatementNoise('- : Acme S.p.A. -'), 'Acme S.p.A.');
    });

    test('indexOfPhrase respects word starts and case', () {
      expect(indexOfPhrase('Banca Ord: X Ord: Y', 'Ord:'), 6, reason: 'Banca Ord: starts a word too');
      expect(indexOfPhrase('WORD:x', 'ORD:'), -1);
      expect(indexOfPhrase('DT.ORD:x', 'ORD:', caseSensitive: true), 3);
      expect(indexOfPhrase('dt.ord:x', 'ORD:', caseSensitive: true), -1);
    });
  });

  group('kind lexicon', () {
    test('phrase syntax: anchors, exact line, prefix', () {
      expect(KindPhrase('^pos').matches(wordsOf('POS SPAR 20170429')), isTrue);
      expect(KindPhrase('^pos').matches(wordsOf('C-POS SPAR')), isFalse);
      expect(KindPhrase('^c-pos').matches(wordsOf('C-POS SPAR')), isTrue);
      expect(KindPhrase(r'^pagamento$').matches(wordsOf('Pagamento')), isTrue);
      expect(KindPhrase(r'^pagamento$').matches(wordsOf('Pagamento con carta')), isFalse);
      expect(KindPhrase('accredit*').matches(wordsOf('Accredita EUR')), isTrue);
      expect(KindPhrase('accredit*').matches(wordsOf('ACCREDITO EMOLUMENTI')), isTrue);
      expect(KindPhrase('fee').matches(wordsOf('coffee shop')), isFalse, reason: 'whole words only');
      expect(KindPhrase('sconto canone').matches(wordsOf('Sconto Canone Mensile')), isTrue);
    });

    test('first matching kind in table order wins', () {
      expect(kindOf('Imposta bollo dossier titoli'), BankEntryKind.tax);
      expect(kindOf('Compravendita Titoli'), BankEntryKind.securitiesTrade);
      expect(kindOf('Ricarica telefonica'), BankEntryKind.cardPayment);
      expect(kindOf('Ricarica'), BankEntryKind.cardTopUp);
      expect(kindOf('Non-Euro Point Of Sales Fee'), BankEntryKind.fee);
      expect(kindOf('xyz'), isNull);
      expect(kindOf(''), isNull);
    });

    test('typeHintOf reads the bank label column case-insensitively', () {
      expect(typeHintOf({'Tipo': 'Prelievo'}), 'Prelievo');
      expect(typeHintOf({'TYPE': ' Card payment '}), 'Card payment');
      expect(typeHintOf({'Descrizione': 'x'}), isNull);
      expect(typeHintOf(null), isNull);
    });
  });
}
