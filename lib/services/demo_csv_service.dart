import 'dart:io';
import 'dart:math';

import '../utils/logger.dart';

final _log = getLogger('DemoCsvService');

/// Generates realistic demo CSV files for the guided tour.
/// Column names are deliberately non-obvious to teach users column mapping,
/// formula builder, and other import wizard features.
class DemoCsvService {
  DemoCsvService._();

  static Future<void> generateDemoCsvs(String directoryPath) async {
    _log.info('Generating demo CSVs in $directoryPath');

    final dir = Directory(directoryPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    await File('$directoryPath/demo_transactions.csv')
        .writeAsString(_generateTransactions());
    await File('$directoryPath/demo_asset_events.csv')
        .writeAsString(_generateAssetEvents());
    await File('$directoryPath/demo_income.csv')
        .writeAsString(_generateIncome());

    _log.info('Demo CSVs generated');
  }

  // ── Transactions ──
  // Uses separate credit/debit columns (Entrate/Uscite) to teach the formula builder.
  // Includes a Saldo (balance) column to teach balance mode.
  // Uses Italian-ish column names that partially auto-map.

  static String _generateTransactions() {
    final rng = Random(42);
    final buf = StringBuffer();
    // 5 junk header rows to teach "Skip Rows" (empty rows are filtered, so user sets skip=5)
    buf.writeln('Bank Export - Checking Account');
    buf.writeln('Period: Sep 2024 - Dec 2024');
    buf.writeln('Account: IT60 X054 2811 1010 0000 0123 456');
    buf.writeln('Generated: 2025-01-02');
    buf.writeln('Currency: EUR');
    buf.writeln('Data Operazione;Entrate;Uscite;Descrizione;Saldo;Stato');

    var balance = 25000.0;
    final start = DateTime(2024, 9, 1);

    for (var m = 0; m < 4; m++) {
      final year = start.year + ((start.month + m - 1) ~/ 12);
      final month = ((start.month + m - 1) % 12) + 1;

      // Salary on 27th
      final salary = 3200.0 + rng.nextInt(300);
      balance += salary;
      buf.writeln('${_d(year, month, 27)};${_amt(salary)};;Monthly salary;${_amt(balance)};Executed');

      // Rent on 1st
      balance -= 850;
      buf.writeln('${_d(year, month, 1)};;${_amt(850)};Rent payment;${_amt(balance)};Executed');

      // Utilities on 15th
      final util = 80.0 + rng.nextInt(40);
      balance -= util;
      buf.writeln('${_d(year, month, 15)};;${_amt(util)};Utilities;${_amt(balance)};Executed');

      // Subscription on 10th
      balance -= 14.99;
      buf.writeln('${_d(year, month, 10)};;${_amt(14.99)};Streaming subscription;${_amt(balance)};Executed');

      // Groceries (3-5 per month)
      final groceryCount = 3 + rng.nextInt(3);
      for (var g = 0; g < groceryCount; g++) {
        final day = 2 + rng.nextInt(26);
        final amt = 30.0 + rng.nextInt(60);
        balance -= amt;
        buf.writeln('${_d(year, month, day)};;${_amt(amt)};Supermarket;${_amt(balance)};Executed');
      }

      // Dining out (1-2 per month)
      final diningCount = 1 + rng.nextInt(2);
      for (var d = 0; d < diningCount; d++) {
        final day = 5 + rng.nextInt(23);
        final amt = 20.0 + rng.nextInt(40);
        balance -= amt;
        buf.writeln('${_d(year, month, day)};;${_amt(amt)};Restaurant;${_amt(balance)};Executed');
      }

      // Transfer to daily spending on 5th
      final transfer = 300.0 + rng.nextInt(100);
      balance -= transfer;
      buf.writeln('${_d(year, month, 5)};;${_amt(transfer)};Transfer to daily account;${_amt(balance)};Executed');

      // Transport on 12th
      final transport = 30.0 + rng.nextInt(20);
      balance -= transport;
      buf.writeln('${_d(year, month, 12)};;${_amt(transport)};Public transport;${_amt(balance)};Executed');
    }

    return buf.toString();
  }

  // ── Asset Events ──
  // Includes commission column to teach fee mapping.
  // Uses real ISINs and realistic prices.

  static String _generateAssetEvents() {
    final rng = Random(43);
    final buf = StringBuffer();
    buf.writeln('Data;Codice ISIN;Operazione;Quantità;Prezzo;Controvalore;Commissione;Divisa;Cambio');

    // Real ETFs — popular European-listed ETFs
    final etfs = [
      ('IE00B4L5Y983', 85.0, 5.0),   // iShares Core MSCI World
      ('LU1650487413', 105.0, 2.0),   // Amundi Euro Gov Bond 1-3Y
      ('IE00BKM4GZ66', 30.0, 3.0),    // iShares Core EM IMI
      ('LU0908500753', 52.0, 4.0),    // Amundi Stoxx Europe 600
    ];

    for (var m = 0; m < 5; m++) {
      final year = 2024;
      final month = 8 + m;
      final adjustedMonth = ((month - 1) % 12) + 1;
      final adjustedYear = year + ((month - 1) ~/ 12);
      final day = 15;

      for (final (isin, basePrice, vol) in etfs) {
        final drift = (rng.nextDouble() - 0.4) * vol;
        final price = basePrice + drift + m * 0.5;
        final budget = switch (isin) {
          'IE00B4L5Y983' => 1000.0,
          'LU1650487413' => 300.0,
          'IE00BKM4GZ66' => 500.0,
          _ => 700.0,
        };
        final qty = (budget / price).floorToDouble();
        final commission = 2.95 + rng.nextDouble() * 2;
        final amount = qty * price + commission;

        buf.writeln(
          '${_d(adjustedYear, adjustedMonth, day)};$isin;Acquisto;${qty.toInt()};${_amt(price)};${_amt(amount)};${_amt(commission)};EUR;1.00',
        );
      }
    }

    return buf.toString();
  }

  // ── Income ──

  static String _generateIncome() {
    final rng = Random(44);
    final buf = StringBuffer();
    buf.writeln('Data;Importo;Tipo;Valuta');

    for (var m = 0; m < 12; m++) {
      final year = 2024;
      final month = ((m) % 12) + 1;
      final adjustedYear = year + (m ~/ 12);
      final salary = 3200.0 + rng.nextInt(300);
      buf.writeln('${_d(adjustedYear, month, 27)};${_amt(salary)};income;EUR');
    }

    // One refund
    buf.writeln('${_d(2024, 6, 15)};${_amt(480.0)};rimborso;EUR');

    return buf.toString();
  }

  // ── Helpers ──

  static String _d(int y, int m, int d) =>
      '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  static String _amt(double v) => v.toStringAsFixed(2);
}
