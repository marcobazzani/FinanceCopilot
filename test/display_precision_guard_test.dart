import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every amount of money on screen has two decimals: never rounded to a whole
/// amount, never shortened ("25K €"). Money is spelled by fmt.currencyFormat
/// (always two decimals) or fmt.amountFormat; a currency format built anywhere
/// else, the compact notation next to a currency, or an amount rounded before
/// it is formatted would round it. Percentages and plain numbers keep their own
/// formats.
void main() {
  test('no amount of money is shown with fewer than two decimals', () {
    final rules = <String, RegExp>{
      'a currency format built outside fmt.currencyFormat': RegExp(
        r'NumberFormat\.(currency|simpleCurrency|compactCurrency|compactSimpleCurrency)\(',
      ),
      'an amount in the compact notation': RegExp(r'NumberFormat\.compact\(.*(sym|symbol|currency|€)'),
      'an amount rounded before it is formatted': RegExp(r'format\([^()]*\.round\(\)\)'),
    };
    final hits = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final formatters = file.path == 'lib/utils/formatters.dart';
      for (final (i, line) in file.readAsLinesSync().indexed) {
        for (final MapEntry(key: why, value: rule) in rules.entries) {
          if (formatters && rule == rules.values.first) continue;
          if (rule.hasMatch(line)) hits.add('${file.path}:${i + 1}: $why: ${line.trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
