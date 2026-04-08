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
