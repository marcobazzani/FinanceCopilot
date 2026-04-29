import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/investing_com_service.dart';
import 'package:finance_copilot/services/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/isin_url_paste_recovery.dart';

Widget _harness({
  required AppDatabase db,
  required Future<String?> Function(Uri) pageFetcher,
  required void Function(InvestingSearchResult) onResolved,
  String userQuery = 'BE0000351602',
  String cacheKey = 'BE0000351602',
  String defaultExchange = 'MIL',
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      marketPriceServiceProvider.overrideWith((ref) =>
          InvestingComService(db, pageFetcher: pageFetcher)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: IsinUrlPasteRecovery(
            userQuery: userQuery,
            cacheKey: cacheKey,
            defaultExchange: defaultExchange,
            onResolved: onResolved,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  late String bondHtml;

  setUpAll(() {
    bondHtml = File('test/fixtures/instrument_page_be0000351602.html').readAsStringSync();
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('renders headline + explanation interpolating user query', (tester) async {
    await tester.pumpWidget(_harness(
      db: db,
      pageFetcher: (_) async => null,
      onResolved: (_) {},
      userQuery: 'BE0000351602',
    ));

    expect(find.byKey(const Key('instrumentNotFoundHeadline')), findsOneWidget);
    expect(find.byKey(const Key('instrumentNotFoundExplanation')), findsOneWidget);
    expect(find.byKey(const Key('pasteUrlField')), findsOneWidget);
    expect(find.byKey(const Key('verifyUrlButton')), findsOneWidget);
    // The explanation should literally contain the user's query.
    final explanation = tester.widget<Text>(find.byKey(const Key('instrumentNotFoundExplanation')));
    expect(explanation.data, contains('BE0000351602'));
  });

  testWidgets('non-http URL → urlInvalidFormat shown inline; onResolved not called', (tester) async {
    var resolvedCalls = 0;
    await tester.pumpWidget(_harness(
      db: db,
      pageFetcher: (_) async => bondHtml,
      onResolved: (_) => resolvedCalls++,
    ));

    await tester.enterText(find.byKey(const Key('pasteUrlField')), 'ftp://www.investing.com/foo');
    await tester.tap(find.byKey(const Key('verifyUrlButton')));
    await tester.pumpAndSettle();

    expect(resolvedCalls, 0);
    expect(find.text('Invalid address. It must start with http:// or https://.'), findsOneWidget);
  });

  testWidgets('valid URL + happy fetcher → onResolved invoked exactly once', (tester) async {
    final captured = <InvestingSearchResult>[];
    await tester.pumpWidget(_harness(
      db: db,
      pageFetcher: (_) async => bondHtml,
      onResolved: captured.add,
    ));

    await tester.enterText(
      find.byKey(const Key('pasteUrlField')),
      'https://www.investing.com/rates-bonds/be0000351602',
    );
    await tester.tap(find.byKey(const Key('verifyUrlButton')));
    await tester.pumpAndSettle();

    expect(captured.length, 1);
    expect(captured.single.cid, 1181400);
  });

  testWidgets('page parse failure → urlParseFailed shown inline', (tester) async {
    var resolvedCalls = 0;
    await tester.pumpWidget(_harness(
      db: db,
      pageFetcher: (_) async => '<html><body>Just a moment...</body></html>',
      onResolved: (_) => resolvedCalls++,
    ));

    await tester.enterText(
      find.byKey(const Key('pasteUrlField')),
      'https://www.investing.com/rates-bonds/be0000351602',
    );
    await tester.tap(find.byKey(const Key('verifyUrlButton')));
    await tester.pumpAndSettle();

    expect(resolvedCalls, 0);
    expect(find.textContaining('instrument data'), findsOneWidget);
  });
}

// MarketPriceService re-export to satisfy unused-import lint when refactoring.
// ignore: unused_element
const _unused = MarketPriceService;
