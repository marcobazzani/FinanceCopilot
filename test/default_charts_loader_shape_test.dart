// The default-charts file is read eagerly and checked: a chart entry that is
// not an object, or a file without a chart list, fails the parse with a
// FormatException naming the problem (it used to surface as a cast error from
// a lazy `cast<>()` view). Category entries of an unknown shape still expand
// to nothing, as before.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/charts/default_charts_loader.dart';

Account _account(int id) => Account(
  id: id,
  name: 'Account $id',
  type: AccountType.bank,
  currency: 'EUR',
  institution: '',
  isActive: true,
  includeInNetWorth: true,
  sortOrder: 0,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

void main() {
  const loader = DefaultChartsLoader();

  List<DashboardChart> parse(String json) => loader.parse(json, activeAccounts: [_account(1)], activeAssets: const [], activeEvents: const []);

  test('category entries: names, signed objects, and anything else expanding to nothing', () {
    final charts = parse(
      jsonEncode({
        'charts': [
          {
            'title': 'Cash',
            'role': 'cash',
            'categories': [
              'all_accounts',
              {'category': 'all_accounts', 'sign': -1},
              42,
              null,
              {'sign': -1},
            ],
          },
        ],
      }),
    );

    expect(charts.single.seriesJson, '[{"type":"account","id":1},{"type":"account","id":1,"sign":-1}]');
  });

  test('a chart entry that is not an object fails the parse and says which', () {
    expect(
      () => parse('{"charts": [{"title": "Cash"}, 3]}'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('#1'))),
    );
  });

  test('a file without a chart list fails the parse', () {
    expect(() => parse('{"graphs": []}'), throwsFormatException);
    expect(() => parse('{"charts": {}}'), throwsFormatException);
    expect(() => parse('[]'), throwsFormatException);
  });

  test('an empty chart list is no charts', () {
    expect(parse('{"charts": []}'), isEmpty);
  });

  test('the bundled file passes the checks', () {
    final charts = parse(File('assets/default_charts.json').readAsStringSync());

    expect(charts, isNotEmpty);
    expect(charts.map((c) => c.sortOrder), [for (var i = 0; i < charts.length; i++) i]);
  });
}
