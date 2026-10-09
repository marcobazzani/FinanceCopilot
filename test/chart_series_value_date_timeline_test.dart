// Chart-level regression: the savings/net-worth series of a `column`-mode
// account whose value dates differ from the bank's booking dates must equal
// the value-date sum of amounts — one timeline. With per-row copies of the
// bank's booking-order balance, a card payment value-dated two days before
// it was booked showed the balance of a LATER day (a dip and a recovery,
// which the cash-flow tab then read as phantom expense and income).
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show allSeriesDataProvider;

class _NoMarket extends MarketPriceService {
  _NoMarket(super.db);
  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
        marketPriceServiceProvider.overrideWithValue(_NoMarket(db)),
        accountsProvider.overrideWithValue(const AsyncData(<Account>[])),
        accountStatsProvider.overrideWithValue(const AsyncData(<int, AccountStats>{})),
        assetsProvider.overrideWithValue(const AsyncData(<Asset>[])),
        assetStatsProvider.overrideWithValue(const AsyncData(<int, AssetStats>{})),
        extraordinaryEventsProvider.overrideWithValue(const AsyncData(<ExtraordinaryEvent>[])),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('re-dated column-mode rows: the account series equals the value-date running sum, no dip', () async {
    final acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'KBC'));
    Future<void> bankRow(DateTime value, DateTime booked, double amount, String stated) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: booked,
            valueDate: value,
            amount: amount,
            description: const Value('x'),
            rawMetadata: Value(jsonEncode({'Column 4': stated})),
          ),
        );
    // Booking order, bank running balance (opening 20134.33):
    await bankRow(DateTime(2022, 5, 9), DateTime(2022, 5, 9), -5000, '15,134.33');
    await bankRow(DateTime(2022, 5, 9), DateTime(2022, 5, 9), -5000, '10,134.33');
    await bankRow(DateTime(2022, 5, 9), DateTime(2022, 5, 9), -5000, '5,134.33');
    await bankRow(DateTime(2022, 5, 8), DateTime(2022, 5, 10), -2500, '2,634.33'); // card payment of the 8th, booked the 10th
    await bankRow(DateTime(2022, 5, 9), DateTime(2022, 5, 11), -2500, '134.33');
    await bankRow(DateTime(2022, 5, 10), DateTime(2022, 5, 11), -134.33, '0.00');

    await TransactionService(db).recalculateBalances(
      acct,
      balanceMode: 'column',
      savedMappings: const {'balanceAfter': 'Column 4'},
      numberLocale: 'en_US',
    );

    final data = (await container.read(allSeriesDataProvider.future))!;
    final series = data.accounts.singleWhere((s) => s.key == 'account:$acct');
    // x is days since firstDate (2022-05-08).
    final byDay = {for (final p in series.spots) p.x.round(): p.y};
    expect(byDay[0], closeTo(17634.33, 1e-6), reason: 'May 8: opening − the card payment; NOT the bank figure 2634.33 booked on the 10th');
    expect(byDay[1], closeTo(134.33, 1e-6), reason: 'May 9: three transfers and the second card payment');
    expect(byDay[2], closeTo(0, 1e-6), reason: 'May 10: closing, equals the bank closing');
    // The very property the cash-flow tab depends on: day-over-day deltas are exactly the day's amounts.
    expect(byDay[0]! - byDay[1]!, closeTo(17500, 1e-6));
    expect(byDay[1]! - byDay[2]!, closeTo(134.33, 1e-6));
  });
}
