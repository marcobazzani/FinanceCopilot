import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/classification/description_normalizer.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoryService cats;
  late RuleService rules;
  late TransactionClassifierService clf;
  late int acctA, acctB;
  late int groceries, transfer, salary, restaurants;

  Future<int> account(String name) => db.into(db.accounts).insert(AccountsCompanion.insert(name: name, currency: const Value('EUR')));

  /// Insert a transaction with derived keys computed like import does.
  Future<int> tx(
    int acct,
    double amount,
    String desc, {
    DateTime? date,
    String currency = 'EUR',
    int? categoryId,
    String? rawMeta,
  }) {
    final d = date ?? DateTime(2024, 3, 10);
    final n = TransactionClassifierService.normalize(description: desc, rawMetadataJson: rawMeta, amount: amount);
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: d,
            valueDate: d,
            amount: amount,
            description: Value(desc),
            currency: Value(currency),
            categoryId: Value(categoryId),
            rawMetadata: Value(rawMeta),
            merchantKey: Value(n.merchantKey),
            counterparty: Value(n.counterparty),
            entryKind: Value(n.entryKind),
          ),
        );
  }

  Future<Transaction> get(int id) => (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cats = CategoryService(db);
    rules = RuleService(db);
    clf = TransactionClassifierService(db);
    acctA = await account('Main');
    acctB = await account('Card');
    groceries = (await cats.getByKey('groceries'))!.id;
    transfer = (await cats.getByKey('transfer'))!.id;
    salary = (await cats.getByKey('salary'))!.id;
    restaurants = (await cats.getByKey('restaurantsBars'))!.id;
  });

  tearDown(() => db.close());

  group('RuleService / CompiledRule', () {
    test('merchantKey match is exact on the normalized key, pattern is upper-cased on save', () async {
      final id = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'esselunga', categoryId: groceries);
      final r = CompiledRule((await rules.getById(id))!);
      expect(r.rule.pattern, 'ESSELUNGA');
      expect(r.matches(const RuleInput(accountId: 1, amount: -10, description: 'x', merchantKey: 'ESSELUNGA')), isTrue);
      expect(r.matches(const RuleInput(accountId: 1, amount: -10, description: 'x', merchantKey: 'ESSELUNGAMILANO')), isFalse);
      expect(r.matches(const RuleInput(accountId: 1, amount: -10, description: 'x', merchantKey: null)), isFalse);
    });

    test('contains is case-insensitive over description + full description', () async {
      final id = await rules.create(matchType: RuleMatchType.contains, pattern: 'John DOE', categoryId: transfer);
      final r = CompiledRule((await rules.getById(id))!);
      expect(r.matches(const RuleInput(accountId: 1, amount: -1, description: 'SCT john doe')), isTrue);
      expect(r.matches(const RuleInput(accountId: 1, amount: -1, description: 'x', descriptionFull: 'Ben: JOHN DOE')), isTrue);
      expect(r.matches(const RuleInput(accountId: 1, amount: -1, description: 'Jane Doe')), isFalse);
    });

    test('regex matches case-insensitively; invalid regex is rejected on create and never matches', () async {
      final id = await rules.create(matchType: RuleMatchType.regex, pattern: r'^pos\s+spar\b', categoryId: groceries);
      final r = CompiledRule((await rules.getById(id))!);
      expect(r.matches(const RuleInput(accountId: 1, amount: -1, description: 'POS SPAR 20170429')), isTrue);
      expect(r.matches(const RuleInput(accountId: 1, amount: -1, description: 'POS SPARKLE')), isFalse);
      expect(
        () => rules.create(matchType: RuleMatchType.regex, pattern: '(unclosed', categoryId: groceries),
        throwsArgumentError,
      );
      // A row that slipped in raw must not throw at evaluation time.
      final rawId = await db
          .into(db.autoCategorizationRules)
          .insert(
            AutoCategorizationRulesCompanion.insert(
              pattern: '(unclosed',
              categoryId: groceries,
              matchType: const Value(RuleMatchType.regex),
            ),
          );
      final bad = CompiledRule((await rules.getById(rawId))!);
      expect(bad.matches(const RuleInput(accountId: 1, amount: -1, description: '(unclosed')), isFalse);
    });

    test('entryKind matches the bank kind name and validates known kinds', () async {
      expect(RuleService.isValidPattern(RuleMatchType.entryKind, 'atmWithdrawal'), isTrue);
      expect(RuleService.isValidPattern(RuleMatchType.entryKind, 'nope'), isFalse);
      final id = await rules.create(matchType: RuleMatchType.entryKind, pattern: 'atmWithdrawal', categoryId: groceries);
      final r = CompiledRule((await rules.getById(id))!);
      expect(r.matches(const RuleInput(accountId: 1, amount: -1, description: 'x', entryKind: BankEntryKind.atmWithdrawal)), isTrue);
      expect(r.matches(const RuleInput(accountId: 1, amount: -1, description: 'x', entryKind: BankEntryKind.fee)), isFalse);
    });

    test('scope: account, direction and amount bounds', () async {
      final id = await rules.create(
        matchType: RuleMatchType.contains,
        pattern: 'acme',
        categoryId: groceries,
        accountId: 7,
        direction: RuleDirection.outflow,
        amountMin: 10,
        amountMax: 100,
      );
      final r = CompiledRule((await rules.getById(id))!);
      RuleInput i({int acct = 7, double amount = -50}) => RuleInput(accountId: acct, amount: amount, description: 'acme');
      expect(r.matches(i()), isTrue);
      expect(r.matches(i(acct: 8)), isFalse, reason: 'other account');
      expect(r.matches(i(amount: 50)), isFalse, reason: 'inflow');
      expect(r.matches(i(amount: -5)), isFalse, reason: 'below min');
      expect(r.matches(i(amount: -500)), isFalse, reason: 'above max');
      expect(r.matches(i(amount: -10)), isTrue, reason: 'bounds inclusive');
      expect(r.matches(i(amount: -100)), isTrue);
    });

    test('evaluation order is priority asc then id; reorder rewrites priorities', () async {
      final a = await rules.create(matchType: RuleMatchType.contains, pattern: 'a', categoryId: groceries);
      final b = await rules.create(matchType: RuleMatchType.contains, pattern: 'b', categoryId: groceries);
      final c = await rules.create(matchType: RuleMatchType.contains, pattern: 'c', categoryId: groceries);
      expect((await rules.getAll()).map((r) => r.id), [a, b, c]);
      await rules.reorder([c, a, b]);
      expect((await rules.getAll()).map((r) => r.id), [c, a, b]);
      await rules.setActive(a, false);
      expect((await rules.getActive()).map((r) => r.id), [c, b]);
    });

    test('creating an exact duplicate reuses (and re-activates) the existing rule', () async {
      final a = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'esselunga', categoryId: groceries);
      await rules.setActive(a, false);
      final b = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      expect(b, a);
      expect((await rules.getById(a))!.isActive, isTrue);
      expect(await rules.getAll(), hasLength(1));
      // Different scope or category is a different rule.
      final c = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries, accountId: acctA);
      final d = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: restaurants);
      expect({a, c, d}, hasLength(3));
    });

    test('update re-normalizes and validates the pattern', () async {
      final id = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'x', categoryId: groceries);
      await rules.update(id, const AutoCategorizationRulesCompanion(pattern: Value(' spar ')));
      expect((await rules.getById(id))!.pattern, 'SPAR');
      await rules.update(id, const AutoCategorizationRulesCompanion(matchType: Value(RuleMatchType.contains)));
      expect((await rules.getById(id))!.pattern, 'spar');
      expect(
        () => rules.update(
          id,
          const AutoCategorizationRulesCompanion(matchType: Value(RuleMatchType.regex), pattern: Value('[')),
        ),
        throwsArgumentError,
      );
    });
  });

  group('CategoryService', () {
    test('seeded categories are ordered and resolvable by key; rename clears the key', () async {
      final all = await cats.getAll();
      expect(all.first.key, 'salary');
      final g = (await cats.getByKey('groceries'))!;
      await cats.rename(g.id, 'Spesa');
      final renamed = (await cats.getById(g.id))!;
      expect(renamed.name, 'Spesa');
      expect(renamed.key, isNull);
      expect(await cats.getByKey('groceries'), isNull);
      // restoreDefaults re-adds the missing seeded one without touching the renamed row.
      expect(await cats.restoreDefaults(), 1);
      expect((await cats.getById(g.id))!.name, 'Spesa');
    });

    test('create appends after the last sortOrder; archived rows hidden by default', () async {
      final id = await cats.create(name: 'Pets', type: CategoryType.expense);
      final all = await cats.getAll();
      expect(all.last.id, id);
      expect(all.last.sortOrder, greaterThan(all[all.length - 2].sortOrder));
      await cats.setArchived(id, true);
      expect((await cats.getAll()).any((c) => c.id == id), isFalse);
      expect((await cats.getAll(includeArchived: true)).any((c) => c.id == id), isTrue);
    });

    test('usage counts and delete with/without reassignment', () async {
      final t1 = await tx(acctA, -10, 'Esselunga', categoryId: groceries);
      await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      final u = await cats.usage(groceries);
      expect(u.transactions, 1);
      expect(u.rules, 1);

      await cats.delete(groceries, reassignTo: restaurants);
      expect((await get(t1)).categoryId, restaurants);
      expect((await rules.getAll()).single.categoryId, restaurants);

      await cats.delete(restaurants);
      expect((await get(t1)).categoryId, isNull);
      expect(await rules.getAll(), isEmpty, reason: 'rules cannot point at nothing');
      expect(() => cats.delete(salary, reassignTo: salary), throwsArgumentError);
    });

    test('reorder persists', () async {
      final all = await cats.getAll();
      final ids = all.map((c) => c.id).toList().reversed.toList();
      await cats.reorder(ids);
      expect((await cats.getAll()).map((c) => c.id), ids);
    });
  });

  group('classifyAll', () {
    test('rules apply in priority order, first match wins; unmatched rows stay uncategorized', () async {
      final t1 = await tx(acctA, -20, 'Esselunga');
      final t2 = await tx(acctA, -8, 'Pizzikotto');
      final t3 = await tx(acctA, -100, 'Something else');
      // Two rules match t1: contains 'ess' (restaurants, created first) and merchantKey (groceries).
      await rules.create(matchType: RuleMatchType.contains, pattern: 'ess', categoryId: restaurants);
      await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'PIZZIKOTTO', categoryId: restaurants);

      final r = await clf.classifyAll();
      expect(r.scanned, 3);
      expect(r.changed, 2);
      expect(r.viaRules, 2);
      expect(r.uncategorizedAfter, 1);
      expect((await get(t1)).categoryId, restaurants, reason: 'first rule in priority order wins');
      expect((await get(t2)).categoryId, restaurants);
      expect((await get(t3)).categoryId, isNull);

      // Reordering the rules and reclassifying with overwrite flips t1.
      final all = await rules.getAll();
      await rules.reorder([all[1].id, all[0].id, all[2].id]);
      expect((await clf.classifyAll()).changed, 0, reason: 'without overwrite categorized rows are untouched');
      final r2 = await clf.classifyAll(overwrite: true);
      expect(r2.changed, 1);
      expect((await get(t1)).categoryId, groceries);
    });

    test('is idempotent', () async {
      await tx(acctA, -20, 'Esselunga');
      await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      expect((await clf.classifyAll()).changed, 1);
      expect((await clf.classifyAll()).changed, 0);
      expect((await clf.classifyAll(overwrite: true)).changed, 0);
    });

    test('overwrite=false never touches categorized rows; overwrite=true leaves non-matching rows alone', () async {
      final manual = await tx(acctA, -20, 'Esselunga', categoryId: restaurants);
      final other = await tx(acctA, -5, 'Bar', categoryId: restaurants);
      await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);

      await clf.classifyAll();
      expect((await get(manual)).categoryId, restaurants);

      await clf.classifyAll(overwrite: true);
      expect((await get(manual)).categoryId, groceries, reason: 'a matching rule wins on overwrite');
      expect((await get(other)).categoryId, restaurants, reason: 'no rule matches → keeps its category');
    });

    group('ledger-explained rows never take part', () {
      test('cross-account transfer pairs are excluded even when a rule would match', () async {
        final d = DateTime(2024, 5, 2);
        final out = await tx(acctA, -500, 'To my card', date: d);
        final inn = await tx(acctB, 500, 'Top-up from main', date: d);
        final lonely = await tx(acctA, -500, 'To my card', date: DateTime(2024, 5, 9));
        await rules.create(matchType: RuleMatchType.contains, pattern: 'top-up', categoryId: salary);
        await rules.create(matchType: RuleMatchType.contains, pattern: 'my card', categoryId: transfer);

        final r = await clf.classifyAll();
        expect(r.excluded, 2);
        expect(r.viaRules, 1, reason: 'only the unpaired row is a candidate');
        expect((await get(out)).categoryId, isNull);
        expect((await get(inn)).categoryId, isNull);
        expect((await get(lonely)).categoryId, transfer, reason: 'unpaired transfers are ordinary rows for rules');
        expect(r.uncategorizedAfter, 0);
      });

      test('same-account no-op pairs are excluded', () async {
        final d = DateTime(2024, 5, 2);
        final a = await tx(acctA, -30, 'Charge', date: d);
        final b = await tx(acctA, 30, 'Charge reversal', date: d);
        await rules.create(matchType: RuleMatchType.contains, pattern: 'charge', categoryId: groceries);
        final r = await clf.classifyAll();
        expect(r.excluded, 2);
        expect((await get(a)).categoryId, isNull);
        expect((await get(b)).categoryId, isNull);
      });

      test('cancelled rows are excluded', () async {
        final id = await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                accountId: acctA,
                operationDate: DateTime(2024, 1, 1),
                valueDate: DateTime(2024, 1, 1),
                amount: -20,
                description: const Value('Esselunga'),
                status: const Value(TransactionStatus.cancelled),
                merchantKey: const Value('ESSELUNGA'),
              ),
            );
        await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
        final r = await clf.classifyAll();
        expect(r.excluded, 1);
        expect((await get(id)).categoryId, isNull);
      });

      test('extraordinary-event anchors are excluded', () async {
        final d = DateTime(2024, 6, 1);
        final anchor = await tx(acctA, -3000, 'Dentist', date: d);
        final normal = await tx(acctA, -30, 'Dentist', date: DateTime(2024, 6, 2));
        await db
            .into(db.extraordinaryEvents)
            .insert(
              ExtraordinaryEventsCompanion.insert(
                name: 'Dental work',
                eventDate: d,
                totalAmount: 3000,
                direction: EventDirection.outflow,
                treatment: EventTreatment.instant,
              ),
            );
        await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'DENTIST', categoryId: groceries);
        final r = await clf.classifyAll();
        expect(r.excluded, 1);
        expect((await get(anchor)).categoryId, isNull);
        expect((await get(normal)).categoryId, groceries);
      });

      test('a category left on an excluded row is cleared by the classifier', () async {
        final d = DateTime(2024, 5, 2);
        final out = await tx(acctA, -500, 'To my card', date: d, categoryId: transfer);
        await tx(acctB, 500, 'Top-up', date: d);
        final r = await clf.classifyAll();
        expect(r.changed, 1);
        expect((await get(out)).categoryId, isNull);
        expect((await clf.classifyAll()).changed, 0, reason: 'idempotent');
      });

      test('excluded rows are out of progress, groups, previews and id snapshots', () async {
        final d = DateTime(2024, 5, 2);
        await tx(acctA, -500, 'Esselunga', date: d);
        await tx(acctB, 500, 'Esselunga', date: d);
        final real = await tx(acctA, -20, 'Esselunga');

        final p = await clf.progress();
        expect(p.total, 1);
        expect(p.excluded, 2);
        expect(p.uncategorized, 1);

        final groups = await clf.watchUncategorizedGroups().first;
        expect(groups.single.count, 1);
        expect(groups.single.latestTransactionId, real);
        expect(await clf.uncategorizedIds(), {real});
        expect(await clf.uncategorizedIdsOf('ESSELUNGA'), [real]);

        final id = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
        final c = await clf.countMatches(CompiledRule((await rules.getById(id))!));
        expect(c.total, 1);
      });

      test('account scope still sees pairs across accounts', () async {
        final d = DateTime(2024, 5, 2);
        final out = await tx(acctA, -500, 'To my card', date: d);
        await tx(acctB, 500, 'Top-up', date: d);
        await rules.create(matchType: RuleMatchType.contains, pattern: 'card', categoryId: transfer);
        final r = await clf.classifyAll(accountId: acctA);
        expect(r.excluded, 1);
        expect((await get(out)).categoryId, isNull);
      });

      test('ledger stream still re-emits on transaction writes when the adjustment stream is subscribed first', () async {
        // Regression: drift shares stream queries by SQL text. A trigger
        // written as `SELECT 1` collided with ExtraordinaryEventService's
        // `SELECT 1` revision stream and inherited ITS table set, so
        // transaction updates were never observed in the running app.
        final adjSub = ExtraordinaryEventService(db).watchAdjustmentRevision().listen((_) {});
        await tx(acctA, -20, 'Esselunga');
        await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
        final seen = <int>[];
        final sub = clf.watchProgress().listen((p) => seen.add(p.categorized));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await clf.classifyAll();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await sub.cancel();
        await adjSub.cancel();
        expect(seen, [0, 1], reason: 'emissions: $seen');
      });

      test('ledger stream re-emits when an extraordinary event is added', () async {
        final d = DateTime(2024, 6, 1);
        await tx(acctA, -3000, 'Dentist', date: d);
        final progress = clf.watchProgress();
        final first = await progress.first;
        expect(first.total, 1);
        await db
            .into(db.extraordinaryEvents)
            .insert(
              ExtraordinaryEventsCompanion.insert(
                name: 'Dental work',
                eventDate: d,
                totalAmount: 3000,
                direction: EventDirection.outflow,
                treatment: EventTreatment.instant,
              ),
            );
        final after = await clf.progress();
        expect(after.total, 0);
        expect(after.excluded, 1);
      });
    });

    test('inactive rules are skipped', () async {
      final t = await tx(acctA, -20, 'Esselunga');
      final id = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      await rules.setActive(id, false);
      await clf.classifyAll();
      expect((await get(t)).categoryId, isNull);
    });

    test('handles more rows than one IN-chunk', () async {
      for (var i = 0; i < 1200; i++) {
        await tx(acctA, -1, 'Esselunga', date: DateTime(2024, 1, 1).add(Duration(minutes: i)));
      }
      await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      final r = await clf.classifyAll();
      expect(r.changed, 1200);
      final p = await clf.progress();
      expect(p.categorized, 1200);
    });
  });

  group('setCategory / countMatches', () {
    test('setCategory sets and clears', () async {
      final a = await tx(acctA, -20, 'A');
      final b = await tx(acctA, -20, 'B');
      expect(await clf.setCategory([a, b], groceries), 2);
      expect((await get(a)).categoryId, groceries);
      expect(await clf.setCategory([a], null), 1);
      expect((await get(a)).categoryId, isNull);
      expect(await clf.setCategory(const [], groceries), 0);
    });

    test('countMatches reports total and uncategorized matches', () async {
      await tx(acctA, -20, 'Esselunga');
      await tx(acctA, -20, 'Esselunga', categoryId: groceries);
      await tx(acctA, -20, 'Other');
      final id = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      final c = await clf.countMatches(CompiledRule((await rules.getById(id))!));
      expect(c.total, 2);
      expect(c.uncategorized, 1);
    });
  });

  group('progress & merchant groups', () {
    test('progress counts', () async {
      await tx(acctA, -20, 'A');
      await tx(acctA, -20, 'B', categoryId: groceries);
      await tx(acctB, -20, 'C');
      final p = await clf.progress();
      expect(p.total, 3);
      expect(p.categorized, 1);
      expect(p.uncategorized, 2);
      expect(p.fraction, closeTo(1 / 3, 1e-9));
      final pa = await clf.progress(accountId: acctA);
      expect(pa.total, 2);
      expect(const ClassificationProgress(total: 0, categorized: 0).fraction, 1.0);
    });

    test('groups merge across accounts and currencies, biggest first, with latest tx id', () async {
      final e1 = await tx(acctA, -20, 'Esselunga', date: DateTime(2024, 1, 5));
      final e2 = await tx(acctB, -30, 'Esselunga', date: DateTime(2024, 3, 5));
      await tx(acctA, -10, 'Esselunga', date: DateTime(2024, 2, 5), currency: 'USD');
      await tx(acctA, -8, 'Pizzikotto');
      await tx(acctA, -8, 'Pizzikotto', categoryId: restaurants);

      final groups = await clf.watchUncategorizedGroups().first;
      expect(groups.map((g) => g.merchantKey), ['ESSELUNGA', 'PIZZIKOTTO']);
      final g = groups.first;
      expect(g.count, 3);
      expect(g.accountIds, {acctA, acctB});
      expect(g.totalByCurrency, {'EUR': 50.0, 'USD': 10.0});
      expect(g.singleCurrencyTotal, isNull);
      expect(g.firstDate, DateTime(2024, 1, 5));
      expect(g.lastDate, DateTime(2024, 3, 5));
      expect(g.latestTransactionId, e2);
      expect(g.counterparty, 'Esselunga');
      expect(g.entryKind, BankEntryKind.unknown);
      expect(groups[1].count, 1, reason: 'categorized rows are excluded');
      expect(groups[1].singleCurrencyTotal, ('EUR', 8.0));

      final scoped = await clf.watchUncategorizedGroups(accountId: acctB).first;
      expect(scoped.single.count, 1);
      expect(scoped.single.latestTransactionId, e2);

      final rows = await clf.uncategorizedOf('ESSELUNGA');
      expect(rows, hasLength(3));
      expect(rows.first.id, e2, reason: 'newest first');
      expect(rows.last.id, e1, reason: 'oldest last');
      expect(await clf.uncategorizedIdsOf('ESSELUNGA', accountId: acctA), hasLength(2));
    });

    test('valued ledger: groups sorted by base-currency money, FX-missing rows excluded and counted, money-based progress', () async {
      // Rates: USD → EUR known; GBP unknown on purpose.
      Future<double?> rate(String cur, int dayKey) async => cur == 'USD' ? 0.5 : null;
      await tx(acctA, -20, 'Esselunga');
      await tx(acctA, -20, 'Esselunga');
      await tx(acctA, -20, 'Esselunga'); // 3 rows, 60 EUR
      await tx(acctA, -1000, 'Dentist', currency: 'USD'); // 1 row, 500 EUR
      await tx(acctA, -9999, 'Harrods', currency: 'GBP'); // no rate: worth 0 for ordering, counted
      await tx(acctA, -8, 'Pizzikotto', categoryId: restaurants);

      final groups = await clf.watchUncategorizedGroups(rate: rate, baseCurrency: 'EUR').first;
      expect(groups.map((g) => g.merchantKey), ['DENTIST', 'ESSELUNGA', 'HARRODS'], reason: 'money first, not row count');
      expect(groups[0].baseTotal, 500);
      expect(groups[1].baseTotal, 60);
      expect(groups[2].baseTotal, 0);
      expect(groups[2].fxMissing, 1);

      final p = await clf.progress(rate: rate, baseCurrency: 'EUR');
      expect(p.total, 6);
      expect(p.categorized, 1);
      expect(p.fxExcluded, 1);
      expect(p.totalAmount, 568);
      expect(p.categorizedAmount, 8);
      expect(p.uncategorizedAmount, 560);
      expect(p.fraction, closeTo(8 / 568, 1e-9), reason: 'progress is money, not rows');
      expect(p.baseCurrency, 'EUR');

      // Without a valuation the old row semantics still hold.
      final rows = await clf.progress();
      expect(rows.totalAmount, isNull);
      expect(rows.fraction, closeTo(1 / 6, 1e-9));
      final byCount = await clf.watchUncategorizedGroups().first;
      expect(byCount.first.merchantKey, 'ESSELUNGA');
    });

    test('groups stream updates after classification', () async {
      await tx(acctA, -20, 'Esselunga');
      await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries);
      expect(await clf.watchUncategorizedGroups().first, hasLength(1));
      await clf.classifyAll();
      expect(await clf.watchUncategorizedGroups().first, isEmpty);
    });
  });

  group('derived keys', () {
    test('a normalizer change re-points merchant-key rules to the keys their rows now carry', () async {
      // Two rows that share an OLD (pre-change) key but normalize to
      // different keys today; plus a rule and an unrelated rule.
      Future<int> oldRow(String desc) => db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acctA,
              operationDate: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              amount: -5,
              description: Value(desc),
              merchantKey: const Value('OLDKEY'),
            ),
          );
      final a = await oldRow('Esselunga');
      final b = await oldRow('Pizzikotto');
      final rule = await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'OLDKEY', categoryId: groceries);
      final other = await rules.create(matchType: RuleMatchType.contains, pattern: 'oldkey', categoryId: groceries);
      await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: kNormalizerVersionKey, value: '0'));

      expect(await clf.recomputeKeysIfStale(), 2);
      expect((await get(a)).merchantKey, 'ESSELUNGA');
      expect((await get(b)).merchantKey, 'PIZZIKOTTO');

      final all = await rules.getAll();
      final merchantRules = all.where((r) => r.matchType == RuleMatchType.merchantKey).toList();
      expect(merchantRules.map((r) => r.pattern).toSet(), {'ESSELUNGA', 'PIZZIKOTTO'});
      expect(merchantRules.any((r) => r.id == rule), isTrue, reason: 'original rule updated in place');
      expect(merchantRules.every((r) => r.categoryId == groceries && r.isActive), isTrue);
      expect((await rules.getById(other))!.pattern, 'oldkey', reason: 'non-merchant rules untouched');

      // The migrated rules still classify the same rows.
      final r = await clf.classifyAll();
      expect(r.changed, 2);
    });

    test('normalize parses raw metadata JSON and tolerates garbage', () {
      final ok = TransactionClassifierService.normalize(
        description: 'Trenitalia',
        rawMetadataJson: '{"Tipo":"Pagamento con carta"}',
        amount: -10,
      );
      expect(ok.entryKind, BankEntryKind.cardPayment);
      final bad = TransactionClassifierService.normalize(description: 'Trenitalia', rawMetadataJson: '{not json', amount: -10);
      expect(bad.merchantKey, 'TRENITALIA');
    });

    test('recomputeKeysIfStale fills missing keys, then does nothing until the version changes', () async {
      // Row inserted without keys (as a pre-v50 row would be).
      final id = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acctA,
              operationDate: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              amount: -5,
              description: const Value('POS SPAR 20170429'),
            ),
          );
      expect(await clf.recomputeKeysIfStale(), 1);
      final t = await get(id);
      expect(t.merchantKey, 'SPAR');
      expect(t.counterparty, 'SPAR');
      expect(t.entryKind, BankEntryKind.cardPayment);

      expect(await clf.recomputeKeysIfStale(), 0);
      final cfg = await (db.select(db.appConfigs)..where((c) => c.key.equals(kNormalizerVersionKey))).getSingle();
      expect(cfg.value, normalizerVersion.toString());

      // Simulate an older normalizer version: every row is rewritten.
      await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: kNormalizerVersionKey, value: '0'));
      expect(await clf.recomputeKeysIfStale(), 1);
      expect(await clf.recomputeKeysIfStale(force: true), 1);
    });
  });
}
