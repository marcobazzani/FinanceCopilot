import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';

Future<void> _pump(WidgetTester tester, Widget child, {required bool isPrivate}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith((ref) => isPrivate),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  group('PrivacyText', () {
    testWidgets('renders plain Text when private=false', (tester) async {
      await _pump(tester, const PrivacyText('hello'), isPrivate: false);
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('wraps in ImageFiltered when private=true', (tester) async {
      await _pump(tester, const PrivacyText('hello'), isPrivate: true);
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });

  group('PrivacyBlur', () {
    testWidgets('returns child unchanged when private=false', (tester) async {
      await _pump(
        tester,
        const PrivacyBlur(child: Text('hello')),
        isPrivate: false,
      );
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('wraps arbitrary child in ImageFiltered when private=true',
        (tester) async {
      await _pump(
        tester,
        const PrivacyBlur(
          child: Row(children: [Text('a'), Text('b')]),
        ),
        isPrivate: true,
      );
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });
}
