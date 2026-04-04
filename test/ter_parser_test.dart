import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/services/composition_service.dart';
import 'package:finance_copilot/database/database.dart';

void main() {
  late CompositionService service;

  setUp(() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    service = CompositionService(db);
  });

  group('parseTerFromInvestingCom', () {
    test('extracts TER from fund DOM (float_lang_base pattern)', () {
      const html = '''
        <div class="inlineblock">
          <span class="float_lang_base_1">Expenses</span>
          <span class="float_lang_base_2 bold">0.84%</span>
        </div>
      ''';
      expect(service.parseTerFromInvestingCom(html), 0.84);
    });

    test('extracts TER from fund DOM with comma decimal', () {
      const html = '''
        <div class="inlineblock">
          <span class="float_lang_base_1">Expenses</span>
          <span class="float_lang_base_2 bold">1,23%</span>
        </div>
      ''';
      expect(service.parseTerFromInvestingCom(html), 1.23);
    });

    test('extracts TER from ETF JSON expenseRatio', () {
      const html = '''
        <script>{"keyMetrics":{"expenseRatio":0.2,"fundOfFunds":false}}</script>
      ''';
      expect(service.parseTerFromInvestingCom(html), 0.2);
    });

    test('prefers DOM over JSON when both present', () {
      const html = '''
        <div>
          <span class="float_lang_base_1">Expenses</span>
          <span class="float_lang_base_2 bold">0.50%</span>
        </div>
        <script>{"expenseRatio":0.3}</script>
      ''';
      expect(service.parseTerFromInvestingCom(html), 0.50);
    });

    test('returns null for bond page (no TER elements)', () {
      // Simulates a bond page: "Expenses" only in JSON translation strings,
      // never in the actual DOM with the correct class, and no expenseRatio
      const html = '''
        <html>
          <body>
            <div class="instrument-header">Bond XS3213330791</div>
            <script>
              {"_financials_field_accrued_expenses_total":"Accrued Expenses, Total",
               "_financials_field_operating_expenses_growth":"Operating Expenses Growth"}
            </script>
            <div>A return of <span style="color:#FF7901">1,731%</span></div>
          </body>
        </html>
      ''';
      expect(service.parseTerFromInvestingCom(html), isNull);
    });

    test('returns null for stock page (no TER elements)', () {
      const html = '''
        <html><body>
          <div class="instrument-header">AMZN</div>
          <script>{"priceChanges":{"pct_1y":30.17}}</script>
        </body></html>
      ''';
      expect(service.parseTerFromInvestingCom(html), isNull);
    });

    test('returns null for empty HTML', () {
      expect(service.parseTerFromInvestingCom(''), isNull);
    });

    test('ignores Expenses in non-matching DOM classes', () {
      const html = '''
        <span class="some_other_class">Expenses</span>
        <span class="value">2.5%</span>
      ''';
      expect(service.parseTerFromInvestingCom(html), isNull);
    });

    test('rejects unreasonable TER values (>= 10%)', () {
      const html = '''
        <div>
          <span class="float_lang_base_1">Expenses</span>
          <span class="float_lang_base_2 bold">15.00%</span>
        </div>
      ''';
      expect(service.parseTerFromInvestingCom(html), isNull);
    });

    test('handles N/A in Expenses field', () {
      const html = '''
        <div>
          <span class="float_lang_base_1">Expenses</span>
          <span class="float_lang_base_2 bold">N/A</span>
        </div>
      ''';
      expect(service.parseTerFromInvestingCom(html), isNull);
    });
  });
}
