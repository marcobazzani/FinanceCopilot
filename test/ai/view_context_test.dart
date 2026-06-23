import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/ai/view_context.dart';

void main() {
  group('aiViewContext', () {
    test('known views return a non-empty description', () {
      for (final v in ['Dashboard', 'Accounts', 'Assets', 'Pillars']) {
        expect(aiViewContext(v), isNotEmpty, reason: v);
      }
    });

    test('Dashboard mentions the charts so "these graphs" is grounded', () {
      final d = aiViewContext('Dashboard').toLowerCase();
      expect(d, contains('net worth'));
      expect(d, contains('cash flow'));
    });

    test('unknown view returns empty', () {
      expect(aiViewContext('Nope'), isEmpty);
    });
  });
}
