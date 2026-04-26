/// Generate XLSX fixture files with proper date/number cell types.
/// Run: dart run integration_test/fixtures/generate_xlsx.dart
library;
import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final dir = File(Platform.script.toFilePath()).parent.path;

  _createTransactionsSimple(dir);
  _createTransactionsFormula(dir);
  _createTransactionsSkipRows(dir);
  _createAssetsTypeColumn(dir);
  _createAssetsSignComputed(dir);
  _createAssetsCurrent(dir);
  _createAssetsMultiIsin(dir);
  _createIncome(dir);
  _createAssetsLive(dir);
  // Realistic multi-year fixtures shaped like the actual broker exports.
  // Mock data only — based on the column structure of FinecoMY.xlsx,
  // Lista Titoli.xlsx, and RevolutIT.csv that the user authored.
  _createFinecoReal(dir);
  _createListaTitoliReal(dir);
  _createRevolutReal(dir);

  // ignore: avoid_print
  print('All XLSX fixtures generated in $dir');
}

void _createTransactionsSimple(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([TextCellValue('Data_Operazione'), TextCellValue('Data_Valuta'), TextCellValue('Amount'), TextCellValue('Description')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 15), DateCellValue(year: 2025, month: 1, day: 15), DoubleCellValue(-42.50), TextCellValue('Supermarket')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 16), DateCellValue(year: 2025, month: 1, day: 16), DoubleCellValue(1500.00), TextCellValue('Salary')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 17), DateCellValue(year: 2025, month: 1, day: 17), DoubleCellValue(-120.00), TextCellValue('Electricity')]);
  File('$dir/transactions_simple.xlsx').writeAsBytesSync(excel.encode()!);
}

void _createTransactionsFormula(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([TextCellValue('Data_Operazione'), TextCellValue('Data_Valuta'), TextCellValue('Debit'), TextCellValue('Credit'), TextCellValue('Description')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 2, day: 10), DateCellValue(year: 2025, month: 2, day: 10), DoubleCellValue(0), DoubleCellValue(2000.00), TextCellValue('Salary')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 2, day: 12), DateCellValue(year: 2025, month: 2, day: 12), DoubleCellValue(150.00), DoubleCellValue(0), TextCellValue('Rent')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 2, day: 15), DateCellValue(year: 2025, month: 2, day: 15), DoubleCellValue(30.00), DoubleCellValue(0), TextCellValue('Groceries')]);
  File('$dir/transactions_formula.xlsx').writeAsBytesSync(excel.encode()!);
}

void _createTransactionsSkipRows(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  // 2 junk header rows
  sheet.appendRow([TextCellValue('Report generated on 2025-03-01')]);
  sheet.appendRow([TextCellValue('Account: Checking 12345')]);
  // Actual data header
  sheet.appendRow([TextCellValue('Data_Operazione'), TextCellValue('Data_Valuta'), TextCellValue('Amount'), TextCellValue('Description')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 3, day: 1), DateCellValue(year: 2025, month: 3, day: 1), DoubleCellValue(-80.00), TextCellValue('Insurance')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 3, day: 5), DateCellValue(year: 2025, month: 3, day: 5), DoubleCellValue(3000.00), TextCellValue('Salary March')]);
  File('$dir/transactions_skip_rows.xlsx').writeAsBytesSync(excel.encode()!);
}

void _createAssetsTypeColumn(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([TextCellValue('date'), TextCellValue('isin'), TextCellValue('type'), TextCellValue('quantity'), TextCellValue('price'), TextCellValue('currency'), TextCellValue('amount'), TextCellValue('commission')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 10), TextCellValue('IE00B4L5Y983'), TextCellValue('Buy'), DoubleCellValue(10), DoubleCellValue(95.50), TextCellValue('EUR'), DoubleCellValue(960.00), DoubleCellValue(5.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 2, day: 15), TextCellValue('IE00B4L5Y983'), TextCellValue('Buy'), DoubleCellValue(5), DoubleCellValue(98.00), TextCellValue('EUR'), DoubleCellValue(495.00), DoubleCellValue(5.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 3, day: 1), TextCellValue('IE00B4L5Y983'), TextCellValue('Sell'), DoubleCellValue(3), DoubleCellValue(100.00), TextCellValue('EUR'), DoubleCellValue(297.00), DoubleCellValue(3.00)]);
  File('$dir/assets_type_column.xlsx').writeAsBytesSync(excel.encode()!);
}

void _createAssetsSignComputed(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([TextCellValue('date'), TextCellValue('isin'), TextCellValue('quantity'), TextCellValue('price'), TextCellValue('currency'), TextCellValue('amount')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 15), TextCellValue('LU0908500753'), DoubleCellValue(20), DoubleCellValue(210.50), TextCellValue('EUR'), DoubleCellValue(4220.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 3, day: 1), TextCellValue('LU0908500753'), DoubleCellValue(-5), DoubleCellValue(215.00), TextCellValue('EUR'), DoubleCellValue(1070.00)]);
  File('$dir/assets_sign_computed.xlsx').writeAsBytesSync(excel.encode()!);
}

void _createAssetsCurrent(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([TextCellValue('isin'), TextCellValue('quantity'), TextCellValue('price'), TextCellValue('currency')]);
  sheet.appendRow([TextCellValue('IE00BKM4GZ66'), DoubleCellValue(15), DoubleCellValue(32.50), TextCellValue('EUR')]);
  sheet.appendRow([TextCellValue('JE00B1VS3770'), DoubleCellValue(8), DoubleCellValue(350.00), TextCellValue('EUR')]);
  File('$dir/assets_current.xlsx').writeAsBytesSync(excel.encode()!);
}

void _createAssetsMultiIsin(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([TextCellValue('date'), TextCellValue('isin'), TextCellValue('quantity'), TextCellValue('price'), TextCellValue('currency'), TextCellValue('amount')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 10), TextCellValue('IE00B4L5Y983'), DoubleCellValue(10), DoubleCellValue(95.00), TextCellValue('EUR'), DoubleCellValue(950.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 10), TextCellValue('LU0908500753'), DoubleCellValue(20), DoubleCellValue(210.00), TextCellValue('EUR'), DoubleCellValue(4200.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 10), TextCellValue('IE00BKM4GZ66'), DoubleCellValue(15), DoubleCellValue(32.00), TextCellValue('EUR'), DoubleCellValue(480.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 2, day: 10), TextCellValue('IE00B4L5Y983'), DoubleCellValue(5), DoubleCellValue(96.00), TextCellValue('EUR'), DoubleCellValue(480.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 2, day: 10), TextCellValue('LU0908500753'), DoubleCellValue(10), DoubleCellValue(212.00), TextCellValue('EUR'), DoubleCellValue(2120.00)]);
  File('$dir/assets_multi_isin.xlsx').writeAsBytesSync(excel.encode()!);
}

void _createIncome(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([TextCellValue('Date'), TextCellValue('Amount')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 15), DoubleCellValue(3500.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 2, day: 15), DoubleCellValue(3500.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 3, day: 15), DoubleCellValue(3600.00)]);
  File('$dir/income.xlsx').writeAsBytesSync(excel.encode()!);
}

void _createAssetsLive(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([TextCellValue('date'), TextCellValue('isin'), TextCellValue('quantity'), TextCellValue('price'), TextCellValue('currency'), TextCellValue('amount')]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 10), TextCellValue('IE00B4L5Y983'), DoubleCellValue(10), DoubleCellValue(95.00), TextCellValue('EUR'), DoubleCellValue(950.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 10), TextCellValue('LU0908500753'), DoubleCellValue(20), DoubleCellValue(210.00), TextCellValue('EUR'), DoubleCellValue(4200.00)]);
  sheet.appendRow([DateCellValue(year: 2025, month: 1, day: 10), TextCellValue('XX00FAKE1234'), DoubleCellValue(5), DoubleCellValue(100.00), TextCellValue('EUR'), DoubleCellValue(500.00)]);
  File('$dir/assets_live.xlsx').writeAsBytesSync(excel.encode()!);
}

// ────────────────────────────────────────────────────────────────────────
// Realistic multi-year fixtures — structure mimics actual broker exports.
// Mock numbers only.
// ────────────────────────────────────────────────────────────────────────

/// Mimics FinecoMY.xlsx: 12 banner rows, then header
/// `Data_Operazione, Data_Valuta, Entrate, Uscite, Descrizione,
///  Descrizione_Completa, Stato, Moneymap`. Multi-year (2020-2025).
/// Caller imports with skipRows=12 + formula amount (Entrate - Uscite).
void _createFinecoReal(String dir) {
  final excel = Excel.createExcel();
  // Excel.createExcel() auto-creates an empty "Sheet1" — append to it
  // (parseFixture picks the first sheet by default).
  final sheet = excel['Sheet1'];

  // 12 banner rows (Fineco's real export has these — Conto Corrente,
  // Intestazione, Periodo, Saldo Iniziale/Finale, Note, Risultati Ricerca,
  // blank rows). The importer's skipRows=12 jumps past all of these.
  sheet.appendRow([TextCellValue('Conto Corrente: 9999999')]);
  sheet.appendRow([TextCellValue('Intestazione Conto Corrente: TEST USER')]);
  sheet.appendRow([TextCellValue('Periodo Dal: 01/01/2020 Al: 31/12/2025')]);
  sheet.appendRow([TextCellValue('')]);
  sheet.appendRow([TextCellValue('Saldo Iniziale: 0,00 - Saldo Finale: 12.345,67')]);
  sheet.appendRow([TextCellValue('Nota: Il saldo iniziale e finale ...')]);
  sheet.appendRow([TextCellValue('')]);
  sheet.appendRow([TextCellValue('Nota: Per le carte di credito ...')]);
  sheet.appendRow([TextCellValue('Nota: Per le carte di debito ...')]);
  sheet.appendRow([TextCellValue('')]);
  sheet.appendRow([TextCellValue('Risultati Ricerca')]);
  sheet.appendRow([TextCellValue('')]);

  // Header row.
  sheet.appendRow([
    TextCellValue('Data_Operazione'),
    TextCellValue('Data_Valuta'),
    TextCellValue('Entrate'),
    TextCellValue('Uscite'),
    TextCellValue('Descrizione'),
    TextCellValue('Descrizione_Completa'),
    TextCellValue('Stato'),
    TextCellValue('Moneymap'),
  ]);

  // Generate ~6 years × 12 months × ~3 rows = ~200 rows. Monthly salary
  // (Entrate), monthly bollo + utilities + groceries (Uscite). Realistic
  // descriptions in Italian, stato 'Contabilizzato'.
  void row({
    required DateTime opDate,
    required DateTime valDate,
    double? credit,
    double? debit,
    required String desc,
    required String descFull,
    String moneymap = '',
  }) {
    sheet.appendRow([
      DateCellValue(year: opDate.year, month: opDate.month, day: opDate.day),
      DateCellValue(year: valDate.year, month: valDate.month, day: valDate.day),
      credit != null ? DoubleCellValue(credit) : TextCellValue(''),
      debit != null ? DoubleCellValue(debit) : TextCellValue(''),
      TextCellValue(desc),
      TextCellValue(descFull),
      TextCellValue('Contabilizzato'),
      TextCellValue(moneymap),
    ]);
  }

  for (var y = 2020; y <= 2025; y++) {
    for (var m = 1; m <= 12; m++) {
      // Monthly stipendio on 27th, growing slightly each year.
      final salaryAmt = 2500.0 + (y - 2020) * 100 + (m % 2 == 0 ? 50 : 0);
      row(
        opDate: DateTime(y, m, 27),
        valDate: DateTime(y, m, 27),
        credit: salaryAmt,
        desc: 'Stipendio',
        descFull: 'Pagamento mese ${m.toString().padLeft(2, "0")}/$y',
        moneymap: 'Stipendio',
      );
      // Monthly bollo on the last day; operation date = next month's first.
      final lastOfMonth = DateTime(y, m + 1, 0);
      final nextMonthFirst = DateTime(y, m, 1).add(Duration(days: lastOfMonth.day));
      row(
        opDate: nextMonthFirst,
        valDate: lastOfMonth,
        debit: 8.43,
        desc: 'Imposta bollo conto corrente',
        descFull:
            'Imposta di bollo del ${lastOfMonth.day.toString().padLeft(2, "0")}.${m.toString().padLeft(2, "0")}.$y',
        moneymap: 'Tasse e tributi',
      );
      // Mid-month utility bill.
      row(
        opDate: DateTime(y, m, 15),
        valDate: DateTime(y, m, 15),
        debit: 80 + (m * 3.5).truncate().toDouble(),
        desc: 'Bolletta',
        descFull: 'Pagamento utenze mese ${m.toString().padLeft(2, "0")}',
        moneymap: 'Utenze',
      );
    }
  }

  File('$dir/fineco_real.xlsx').writeAsBytesSync(excel.encode()!);
}

/// Mimics Lista Titoli.xlsx: 6 banner/header rows then column header
/// `Operazione, Data valuta, Descrizione, Titolo, Isin, Segno, Quantita,
///  Divisa, Prezzo, Cambio, Controvalore`. Segno is 'A' (acquisto) or 'V'
/// (vendita). Caller imports with skipRows=5 + type-from-column with
/// buyValues={'A'} sellValues={'V'}.
void _createListaTitoliReal(String dir) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

  // 5 banner rows.
  sheet.appendRow([TextCellValue('Dossier n.: 9999999')]);
  sheet.appendRow([TextCellValue('Intestazione Dossier: TEST USER')]);
  sheet.appendRow([TextCellValue('')]);
  sheet.appendRow([TextCellValue('RISULTATO RICERCA MOVIMENTI TITOLI')]);
  sheet.appendRow([TextCellValue('')]);
  // Header row at index 5.
  sheet.appendRow([
    TextCellValue('Operazione'),
    TextCellValue('Data valuta'),
    TextCellValue('Descrizione'),
    TextCellValue('Titolo'),
    TextCellValue('Isin'),
    TextCellValue('Segno'),
    TextCellValue('Quantita'),
    TextCellValue('Divisa'),
    TextCellValue('Prezzo'),
    TextCellValue('Cambio'),
    TextCellValue('Controvalore'),
  ]);

  void buy({
    required DateTime op,
    required DateTime val,
    required String titolo,
    required String isin,
    required double qty,
    required double price,
    bool sell = false,
  }) {
    sheet.appendRow([
      DateCellValue(year: op.year, month: op.month, day: op.day),
      DateCellValue(year: val.year, month: val.month, day: val.day),
      TextCellValue('Compravendita Titoli'),
      TextCellValue(titolo),
      TextCellValue(isin),
      TextCellValue(sell ? 'V' : 'A'),
      DoubleCellValue(qty),
      TextCellValue('EUR'),
      DoubleCellValue(price),
      DoubleCellValue(1.0),
      DoubleCellValue(qty * price),
    ]);
  }

  // Multi-year holdings — same ISINs reused across years to test dedup
  // and multi-asset aggregation in the dashboard.
  buy(op: DateTime(2020, 3, 5), val: DateTime(2020, 3, 9),
      titolo: 'ISHS CR WD USD-AC', isin: 'IE00B4L5Y983', qty: 25, price: 65.50);
  buy(op: DateTime(2020, 6, 12), val: DateTime(2020, 6, 16),
      titolo: 'LIF C S EU 600 UEAC', isin: 'LU0908500753', qty: 10, price: 175.20);
  buy(op: DateTime(2021, 4, 8), val: DateTime(2021, 4, 12),
      titolo: 'ISHS CR WD USD-AC', isin: 'IE00B4L5Y983', qty: 18, price: 82.10);
  buy(op: DateTime(2021, 9, 14), val: DateTime(2021, 9, 16),
      titolo: 'ISHS MSCI EM USD-AC', isin: 'IE00BKM4GZ66', qty: 40, price: 33.40);
  buy(op: DateTime(2022, 2, 22), val: DateTime(2022, 2, 24),
      titolo: 'XTR2 EUR OR SW 1CC', isin: 'LU0290358497', qty: 50, price: 132.80);
  buy(op: DateTime(2022, 11, 3), val: DateTime(2022, 11, 7),
      titolo: 'UBS COMPOS USD-A-AC', isin: 'IE00B53H0131', qty: 12, price: 95.40);
  buy(op: DateTime(2023, 5, 18), val: DateTime(2023, 5, 22),
      titolo: 'MUL L 1-3Y IG CC', isin: 'LU1650487413', qty: 8, price: 122.10);
  buy(op: DateTime(2023, 9, 1), val: DateTime(2023, 9, 5),
      titolo: 'ISHS CR WD USD-AC', isin: 'IE00B4L5Y983', qty: 12, price: 78.77);
  buy(op: DateTime(2024, 3, 15), val: DateTime(2024, 3, 19),
      titolo: 'XTR2 EUR OR SW 1CC', isin: 'LU0290358497', qty: 80, price: 138.50);
  buy(op: DateTime(2024, 7, 22), val: DateTime(2024, 7, 24),
      titolo: 'ISHS CR WD USD-AC', isin: 'IE00B4L5Y983', qty: 5, price: 95.00,
      sell: true);
  buy(op: DateTime(2025, 2, 18), val: DateTime(2025, 2, 20),
      titolo: 'ISHS CR WD USD-AC', isin: 'IE00B4L5Y983', qty: 47, price: 108.69);
  buy(op: DateTime(2025, 5, 12), val: DateTime(2025, 5, 14),
      titolo: 'XTR2 EUR OR SW 1CC', isin: 'LU0290358497', qty: 100, price: 146.19);
  buy(op: DateTime(2025, 10, 13), val: DateTime(2025, 10, 15),
      titolo: 'XTR2 EUR OR SW 1CC', isin: 'LU0290358497', qty: 169, price: 147.43);

  File('$dir/lista_titoli_real.xlsx').writeAsBytesSync(excel.encode()!);
}

/// Mimics RevolutIT.csv: header `Tipo, Prodotto, Data di inizio, Data di
/// completamento, Descrizione, Importo, Costo, Valuta, State, Saldo`.
/// Saldo is the running balance — caller imports with balanceMode='column'
/// mapped to the Saldo field, cumulative for amount, ISO-style timestamps
/// in the date columns. Mixed Tipo values (Pagamento / Ricarica /
/// Rimborso / Commissione / Pagamento con carta).
void _createRevolutReal(String dir) {
  final buf = StringBuffer();
  buf.writeln(
      'Tipo,Prodotto,Data di inizio,Data di completamento,Descrizione,Importo,Costo,Valuta,State,Saldo');
  // Generate ~50 rows across 2020-2025 with running balance maintained.
  var bal = 0.0;
  void r(String tipo, DateTime d, String desc, double importo, double costo) {
    bal += importo - costo;
    final ts =
        '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")} 12:00:00';
    buf.writeln(
        '$tipo,Attuale,$ts,$ts,"$desc",${importo.toStringAsFixed(2)},${costo.toStringAsFixed(2)},EUR,COMPLETATO,${bal.toStringAsFixed(2)}');
  }

  // 2020 — opening top-up + a few payments.
  r('Ricarica', DateTime(2020, 1, 5), 'Ricarica conto', 200.0, 0);
  r('Pagamento con carta', DateTime(2020, 2, 14), 'Restaurant Roma', -45.50, 0);
  r('Pagamento con carta', DateTime(2020, 4, 3), 'Online shopping', -89.99, 0);
  r('Cambia valuta', DateTime(2020, 6, 10), 'EUR -> USD conversion', -50.0, 0.5);
  r('Ricarica', DateTime(2020, 9, 2), 'Top up monthly', 300.0, 0);
  r('Pagamento', DateTime(2020, 11, 25), 'Friend transfer', -20.0, 0);
  // 2021
  r('Ricarica', DateTime(2021, 1, 8), 'Top up', 250.0, 0);
  r('Pagamento con carta', DateTime(2021, 3, 17), 'Hotel booking', -180.0, 0);
  r('Rimborso', DateTime(2021, 4, 1), 'Refund hotel', 30.0, 0);
  r('Commissione', DateTime(2021, 5, 15), 'Currency fee', -2.50, 0);
  r('Pagamento con carta', DateTime(2021, 7, 22), 'Groceries', -75.30, 0);
  r('Ricompensa', DateTime(2021, 12, 28), 'Cashback bonus', 5.0, 0);
  // 2022
  r('Ricarica', DateTime(2022, 1, 6), 'Salary top-up', 500.0, 0);
  r('Pagamento con carta', DateTime(2022, 2, 11), 'Subscription Netflix', -12.99, 0);
  r('Pagamento con carta', DateTime(2022, 4, 19), 'Flight booking', -245.0, 0);
  r('Rimborso su carta', DateTime(2022, 5, 30), 'Cancelled flight refund', 245.0, 0);
  r('Pagamento con carta', DateTime(2022, 8, 8), 'Restaurant', -55.0, 0);
  r('Prelievo', DateTime(2022, 11, 14), 'ATM withdrawal', -100.0, 1.50);
  // 2023
  r('Ricarica', DateTime(2023, 2, 3), 'Top up', 400.0, 0);
  r('Pagamento con carta', DateTime(2023, 3, 22), 'Online shopping', -134.20, 0);
  r('Cambia valuta', DateTime(2023, 5, 18), 'EUR -> GBP', -100.0, 0.99);
  r('Pagamento', DateTime(2023, 7, 5), 'Friend lunch', -25.50, 0);
  r('Chargeback su carta', DateTime(2023, 8, 12), 'Disputed charge reversed', 89.99, 0);
  r('Pagamento con carta', DateTime(2023, 10, 20), 'Hotel Milano', -210.0, 0);
  // 2024
  r('Ricarica', DateTime(2024, 1, 11), 'Top up new year', 600.0, 0);
  r('Pagamento con carta', DateTime(2024, 2, 28), 'Online shopping', -78.50, 0);
  r('Pagamento con carta', DateTime(2024, 5, 4), 'Restaurant', -42.0, 0);
  r('Commissione', DateTime(2024, 5, 4), 'FX fee', -0.50, 0);
  r('Rimborso', DateTime(2024, 6, 17), 'Friend repaid lunch', 25.50, 0);
  r('Pagamento con carta', DateTime(2024, 9, 9), 'Subscription Spotify', -9.99, 0);
  r('Pagamento con carta', DateTime(2024, 12, 1), 'Holiday gifts', -180.0, 0);
  // 2025
  r('Ricarica', DateTime(2025, 1, 7), 'Top up', 500.0, 0);
  r('Pagamento con carta', DateTime(2025, 2, 14), 'Restaurant Valentino', -85.0, 0);
  r('Pagamento con carta', DateTime(2025, 3, 11), 'Online shopping', -55.0, 0);
  r('Cambia valuta', DateTime(2025, 4, 22), 'EUR -> USD', -200.0, 1.50);
  r('Pagamento con carta', DateTime(2025, 6, 5), 'Restaurant', -42.0, 0);
  r('Rimborso', DateTime(2025, 7, 18), 'Refund product', 55.0, 0);
  r('Pagamento con carta', DateTime(2025, 9, 22), 'Concert tickets', -120.0, 0);
  r('Pagamento con carta', DateTime(2025, 11, 11), 'Black Friday deal', -89.99, 0);
  r('Pagamento con carta', DateTime(2025, 12, 19), 'Christmas gifts', -180.0, 0);

  File('$dir/revolut_real.csv').writeAsString(buf.toString());
}
