// Moving the classifier setup (categories and rules) from one database to
// another through a JSON file: the rules built on a dev copy must arrive on
// the real database without redoing the work, mapped to that database's own
// categories and accounts, and an unreadable file must change nothing.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/classification/description_normalizer.dart' show normalizerVersion;
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/rule_transfer_service.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;

  // Two databases at once, by design: the one exported from and the one
  // imported into.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<int> keyed(AppDatabase db, String key) async => (await CategoryService(db).getByKey(key))!.id;
  Future<int> account(AppDatabase db, String name) => db.into(db.accounts).insert(AccountsCompanion.insert(name: name));

  /// A categorization setup with every kind of rule and category edit.
  Future<void> seedSource() async {
    final fineco = await account(source, 'Fineco');
    final cats = CategoryService(source);
    final pets = await cats.create(name: 'Pets', type: CategoryType.expense, icon: 'pets', color: 'FF795548');
    final groceries = await keyed(source, 'groceries');
    await cats.update(groceries, const CategoriesCompanion(color: Value('FF000000'), isEssential: Value(false)));
    await cats.setArchived(await keyed(source, 'cash'), true);
    final rules = RuleService(source);
    await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: groceries, direction: RuleDirection.outflow);
    await rules.create(matchType: RuleMatchType.contains, pattern: 'Farmacia', categoryId: await keyed(source, 'health'));
    await rules.create(
      matchType: RuleMatchType.regex,
      pattern: r'^bar\b',
      categoryId: await keyed(source, 'restaurantsBars'),
      amountMin: 1,
      amountMax: 50,
    );
    await rules.create(matchType: RuleMatchType.entryKind, pattern: 'atmWithdrawal', categoryId: await keyed(source, 'cash'), accountId: fineco);
    await rules.create(matchType: RuleMatchType.merchantKey, pattern: 'CLINICA VET', categoryId: pets, isActive: false);
  }

  /// [db]'s rules in evaluation order, by what they mean rather than by ids.
  Future<List<String>> describeRules(AppDatabase db) async {
    final cats = {for (final c in await CategoryService(db).getAll(includeArchived: true)) c.id: c};
    final accounts = {for (final a in await db.select(db.accounts).get()) a.id: a.name};
    return [
      for (final r in await RuleService(db).getAll())
        [
          r.matchType.name,
          r.pattern,
          cats[r.categoryId]!.key ?? cats[r.categoryId]!.name,
          r.direction.name,
          r.amountMin,
          r.amountMax,
          r.isActive,
          r.accountId == null ? '-' : accounts[r.accountId],
        ].join('|'),
    ];
  }

  /// [db]'s categories in display order, by what they mean rather than by ids.
  Future<List<String>> describeCategories(AppDatabase db) async => [
    for (final c in await CategoryService(db).getAll(includeArchived: true))
      [c.key ?? c.name, c.type.name, c.icon, c.color, c.isEssential, c.isArchived].join('|'),
  ];

  Future<RuleFile> exported(AppDatabase db) async => RuleTransferService.parse(utf8.encode((await RuleTransferService(db).exportJson()).json));

  List<int> fileBytes(Map<String, Object?> json) => utf8.encode(jsonEncode(json));

  Map<String, Object?> minimalFile({List<Map<String, Object?>>? categories, List<Map<String, Object?>>? rules}) => {
    'format': RuleTransferService.formatId,
    'version': 1,
    'normalizerVersion': normalizerVersion,
    'categories':
        categories ??
        [
          {
            'id': 1,
            'key': 'groceries',
            'name': 'groceries',
            'type': 'expense',
            'icon': null,
            'color': null,
            'isEssential': true,
            'isArchived': false,
          },
        ],
    'rules':
        rules ??
        [
          {
            'matchType': 'merchantKey',
            'pattern': 'ESSELUNGA',
            'categoryId': 1,
            'direction': 'outflow',
            'amountMin': null,
            'amountMax': null,
            'isActive': true,
            'account': null,
          },
        ],
  };

  Matcher problem(RuleFileProblem p) => throwsA(isA<RuleFileException>().having((e) => e.problem, 'problem', p));

  group('export', () {
    test('holds every category, archived ones too, in display order and every rule in evaluation order', () async {
      await seedSource();
      final export = await RuleTransferService(source).exportJson(now: DateTime.utc(2026, 10, 7, 9, 30));
      final json = jsonDecode(export.json) as Map<String, dynamic>;

      expect(json['format'], RuleTransferService.formatId);
      expect(json['version'], 1);
      expect(json['normalizerVersion'], normalizerVersion);
      expect(json['exportedAt'], '2026-10-07T09:30:00.000Z');
      final categories = await CategoryService(source).getAll(includeArchived: true);
      expect([for (final c in json['categories'] as List) c['id']], [for (final c in categories) c.id]);
      expect(export.categories, categories.length);
      expect((json['categories'] as List).where((c) => c['isArchived'] == true).map((c) => c['key']), ['cash']);

      final rules = await RuleService(source).getAll();
      expect(export.rules, 5);
      expect([for (final r in json['rules'] as List) r['pattern']], [for (final r in rules) r.pattern]);
      final regex = (json['rules'] as List)[2] as Map<String, dynamic>;
      expect(regex, {
        'matchType': 'regex',
        'pattern': r'^bar\b',
        'categoryId': await keyed(source, 'restaurantsBars'),
        'direction': 'any',
        'amountMin': 1.0,
        'amountMax': 50.0,
        'isActive': true,
        'account': null,
      });
      expect((json['rules'] as List)[3]['account'], {'id': 1, 'name': 'Fineco'});
    });

    test('a rule whose account was deleted keeps its account id without a name', () async {
      final gone = await account(source, 'Closed');
      await RuleService(
        source,
      ).create(matchType: RuleMatchType.contains, pattern: 'x', categoryId: await keyed(source, 'other'), accountId: gone);
      await (source.delete(source.accounts)..where((a) => a.id.equals(gone))).go();

      final json = jsonDecode((await RuleTransferService(source).exportJson()).json) as Map<String, dynamic>;
      expect((json['rules'] as List).single['account'], {'id': gone, 'name': null});
    });

    test('the file name carries the day of the export', () {
      expect(RuleTransferService.fileNameFor(DateTime(2026, 10, 7, 23, 59)), 'FinanceCopilot-rules-2026-10-07.json');
    });
  });

  group('import', () {
    test('a fresh database gets the same categories and rules, in the same order', () async {
      await seedSource();
      await account(target, 'Other'); // so that Fineco gets another id here
      await account(target, 'Fineco');

      final result = await RuleTransferService(target).importFile(await exported(source));

      expect(await describeRules(target), await describeRules(source));
      expect(await describeCategories(target), await describeCategories(source));
      expect(result.rulesImported, 5);
      expect(result.rulesReplaced, 0);
      expect(result.categoriesAdded, 1, reason: 'only Pets is new: the seeded defaults are matched by key');
      expect(result.rulesSkipped, 0);
      final scoped = (await RuleService(target).getAll()).singleWhere((r) => r.matchType == RuleMatchType.entryKind);
      expect(scoped.accountId, 2, reason: "this database's Fineco");
    });

    test('replaces the rules the device had and keeps its other categories and their transactions', () async {
      await seedSource();
      final garden = await CategoryService(target).create(name: 'Garden', type: CategoryType.expense);
      await RuleService(target).create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGA', categoryId: await keyed(target, 'shopping'));
      final acct = await account(target, 'Main');
      final tx = await target
          .into(target.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acct,
              operationDate: DateTime(2026, 9, 1),
              valueDate: DateTime(2026, 9, 1),
              amount: -12,
              categoryId: Value(garden),
            ),
          );

      final result = await RuleTransferService(target).importFile(await exported(source));

      expect(result.rulesReplaced, 1);
      expect(await describeRules(target), isNot(contains(startsWith('merchantKey|ESSELUNGA|shopping'))));
      expect((await describeRules(target)).length, 4, reason: "the Fineco rule is left out: this device has no Fineco");
      final categories = await CategoryService(target).getAll(includeArchived: true);
      expect(categories.last.id, garden, reason: "this device's other categories come after the file's");
      final row = await (target.select(target.transactions)..where((t) => t.id.equals(tx))).getSingle();
      expect(row.categoryId, garden);
    });

    test('importing the same file again changes nothing', () async {
      await seedSource();
      await account(target, 'Fineco');
      final file = await exported(source);
      await RuleTransferService(target).importFile(file);
      final rules = await describeRules(target);
      final categories = await describeCategories(target);

      final again = await RuleTransferService(target).importFile(file);

      expect(again.categoriesAdded, 0);
      expect(again.rulesReplaced, 5);
      expect(await describeRules(target), rules);
      expect(await describeCategories(target), categories);
    });

    test('a category matches by its seeded key, else by name ignoring case and only of the same type', () async {
      final pets = await CategoryService(target).create(name: 'Pets', type: CategoryType.expense);
      final gifts = await CategoryService(target).create(name: 'Gifts', type: CategoryType.expense);
      final file = RuleTransferService.parse(
        fileBytes(
          minimalFile(
            categories: [
              {
                'id': 1,
                'key': null,
                'name': 'pets',
                'type': 'expense',
                'icon': 'pets',
                'color': null,
                'isEssential': false,
                'isArchived': false,
              },
              {'id': 2, 'key': null, 'name': 'Gifts', 'type': 'income', 'icon': null, 'color': null, 'isEssential': false, 'isArchived': false},
              {
                'id': 3,
                'key': 'groceries',
                'name': 'groceries',
                'type': 'expense',
                'icon': 'shopping_cart',
                'color': 'FF111111',
                'isEssential': true,
                'isArchived': false,
              },
            ],
            rules: [],
          ),
        ),
      );

      final result = await RuleTransferService(target).importFile(file);

      expect(result.categoriesAdded, 1, reason: 'Gifts as income is another category than Gifts as expense');
      final matched = (await CategoryService(target).getById(pets))!;
      expect((matched.name, matched.icon), ('pets', 'pets'));
      expect((await CategoryService(target).getById(gifts))!.type, CategoryType.expense);
      final groceries = (await CategoryService(target).getByKey('groceries'))!;
      expect(groceries.color, 'FF111111');
      expect(groceries.name, 'groceries');
      expect((await CategoryService(target).getAll(includeArchived: true)).where((c) => c.key == 'groceries'), hasLength(1));
    });

    test('a seeded category deleted on this device comes back with its key', () async {
      await RuleService(source).create(matchType: RuleMatchType.merchantKey, pattern: 'RYANAIR', categoryId: await keyed(source, 'travel'));
      await CategoryService(target).delete(await keyed(target, 'travel'));

      final result = await RuleTransferService(target).importFile(await exported(source));

      expect(result.categoriesAdded, 1);
      expect(await describeRules(target), ['merchantKey|RYANAIR|travel|any|null|null|true|-']);
    });

    test('a rule for an account is mapped by name and, without that account here, left out instead of applied to every account', () async {
      final fineco = await account(source, 'Fineco');
      final revolut = await account(source, 'Revolut');
      final rules = RuleService(source);
      final other = await keyed(source, 'other');
      await rules.create(matchType: RuleMatchType.contains, pattern: 'fineco', categoryId: other, accountId: fineco);
      await rules.create(matchType: RuleMatchType.contains, pattern: 'revolut', categoryId: other, accountId: revolut);
      await account(target, 'Fineco');

      final result = await RuleTransferService(target).importFile(await exported(source));

      expect(result.rulesImported, 1);
      expect(result.rulesSkipped, 1);
      expect(result.missingAccounts, ['Revolut']);
      expect(await describeRules(target), ['contains|fineco|other|any|null|null|true|Fineco']);
    });

    test('of two accounts of the same name the rule takes the one with its id; neither, and it is left out', () async {
      RuleFile file(int id) => RuleTransferService.parse(
        fileBytes(
          minimalFile(
            rules: [
              {
                'matchType': 'contains',
                'pattern': 'x',
                'categoryId': 1,
                'direction': 'any',
                'amountMin': null,
                'amountMax': null,
                'isActive': true,
                'account': {'id': id, 'name': 'Conto'},
              },
            ],
          ),
        ),
      );
      await account(target, 'Conto');
      final second = await account(target, 'Conto');

      await RuleTransferService(target).importFile(file(second));
      expect((await RuleService(target).getAll()).single.accountId, second);

      final none = await RuleTransferService(target).importFile(file(99));
      expect(none.rulesSkipped, 1);
      expect(await RuleService(target).getAll(), isEmpty);
    });

    test('a rule whose account was deleted on the exporting device is left out and reported by its id', () async {
      final gone = await account(source, 'Closed');
      await RuleService(
        source,
      ).create(matchType: RuleMatchType.contains, pattern: 'x', categoryId: await keyed(source, 'other'), accountId: gone);
      await (source.delete(source.accounts)..where((a) => a.id.equals(gone))).go();

      final result = await RuleTransferService(target).importFile(await exported(source));

      expect(result.missingAccounts, ['#$gone']);
      expect(await RuleService(target).getAll(), isEmpty);
    });

    test('a rule repeated in the file is created once, active if any copy is', () async {
      Map<String, Object?> rule(bool active) => {
        'matchType': 'merchantKey',
        'pattern': 'ESSELUNGA',
        'categoryId': 1,
        'direction': 'outflow',
        'amountMin': null,
        'amountMax': null,
        'isActive': active,
        'account': null,
      };
      final file = RuleTransferService.parse(fileBytes(minimalFile(rules: [rule(false), rule(true)])));

      final result = await RuleTransferService(target).importFile(file);

      expect(result.rulesImported, 1);
      expect((await RuleService(target).getAll()).single.isActive, isTrue);
    });

    test('an import that fails half way leaves the rules and categories as they were', () async {
      await RuleService(target).create(matchType: RuleMatchType.merchantKey, pattern: 'KEEP', categoryId: await keyed(target, 'shopping'));
      final rules = await describeRules(target);
      final categories = await describeCategories(target);
      // Not a parsed file: its second rule points at a category it does not carry.
      const broken = RuleFile(
        categories: [
          RuleFileCategory(
            id: 1,
            key: null,
            name: 'Brand new',
            type: CategoryType.expense,
            icon: null,
            color: null,
            isEssential: false,
            isArchived: false,
          ),
        ],
        rules: [
          RuleFileRule(
            matchType: RuleMatchType.contains,
            pattern: 'a',
            categoryId: 1,
            direction: RuleDirection.any,
            amountMin: null,
            amountMax: null,
            isActive: true,
            account: null,
          ),
          RuleFileRule(
            matchType: RuleMatchType.contains,
            pattern: 'b',
            categoryId: 2,
            direction: RuleDirection.any,
            amountMin: null,
            amountMax: null,
            isActive: true,
            account: null,
          ),
        ],
      );

      await expectLater(RuleTransferService(target).importFile(broken), throwsA(anything));

      expect(await describeRules(target), rules);
      expect(await describeCategories(target), categories);
    });
  });

  group('parse', () {
    test('reads the file it exported, patterns in stored form and whole amounts as numbers', () {
      final file = RuleTransferService.parse(
        fileBytes(
          minimalFile(
            rules: [
              {
                'matchType': 'merchantKey',
                'pattern': ' esselunga ',
                'categoryId': 1,
                'direction': 'outflow',
                'amountMin': 5,
                'amountMax': 7.5,
                'isActive': true,
                'account': null,
              },
            ],
          ),
        ),
      );
      expect(file.rules.single.pattern, 'ESSELUNGA');
      expect(file.rules.single.amountMin, 5.0);
      expect(file.rules.single.amountMax, 7.5);
    });

    test('refuses what is not a rules export', () {
      expect(() => RuleTransferService.parse(utf8.encode('not json')), problem(RuleFileProblem.notRulesFile));
      expect(() => RuleTransferService.parse([0xff, 0xfe, 0x00]), problem(RuleFileProblem.notRulesFile));
      expect(() => RuleTransferService.parse(utf8.encode('[]')), problem(RuleFileProblem.notRulesFile));
      expect(() => RuleTransferService.parse(fileBytes({...minimalFile(), 'format': 'other'})), problem(RuleFileProblem.notRulesFile));
    });

    test('refuses a newer format version and an unreadable one', () {
      expect(() => RuleTransferService.parse(fileBytes({...minimalFile(), 'version': 2})), problem(RuleFileProblem.newerVersion));
      expect(() => RuleTransferService.parse(fileBytes({...minimalFile(), 'version': '1'})), problem(RuleFileProblem.invalidContent));
      expect(() => RuleTransferService.parse(fileBytes({...minimalFile(), 'version': 0})), problem(RuleFileProblem.invalidContent));
    });

    test('refuses merchant rules built by another normalizer version, and only those', () {
      expect(
        () => RuleTransferService.parse(fileBytes({...minimalFile(), 'normalizerVersion': normalizerVersion + 1})),
        problem(RuleFileProblem.normalizerMismatch),
      );
      expect(() => RuleTransferService.parse(fileBytes({...minimalFile(), 'normalizerVersion': null})), problem(RuleFileProblem.invalidContent));
      final contains = minimalFile(
        rules: [
          {
            'matchType': 'contains',
            'pattern': 'bar',
            'categoryId': 1,
            'direction': 'any',
            'amountMin': null,
            'amountMax': null,
            'isActive': true,
            'account': null,
          },
        ],
      );
      expect(RuleTransferService.parse(fileBytes({...contains, 'normalizerVersion': normalizerVersion + 1})).rules, hasLength(1));
    });

    test('refuses content that does not hold together', () {
      Map<String, Object?> rule(Map<String, Object?> change) => {
        'matchType': 'merchantKey',
        'pattern': 'X',
        'categoryId': 1,
        'direction': 'any',
        'amountMin': null,
        'amountMax': null,
        'isActive': true,
        'account': null,
        ...change,
      };
      Map<String, Object?> category(Map<String, Object?> change) => {
        'id': 1,
        'key': null,
        'name': 'Pets',
        'type': 'expense',
        'icon': null,
        'color': null,
        'isEssential': false,
        'isArchived': false,
        ...change,
      };
      final broken = <String, Map<String, Object?>>{
        'unknown match type': minimalFile(
          rules: [
            rule({'matchType': 'fuzzy'}),
          ],
        ),
        'unknown direction': minimalFile(
          rules: [
            rule({'direction': 'sideways'}),
          ],
        ),
        'invalid regex': minimalFile(
          rules: [
            rule({'matchType': 'regex', 'pattern': '('}),
          ],
        ),
        'unknown entry kind': minimalFile(
          rules: [
            rule({'matchType': 'entryKind', 'pattern': 'teleport'}),
          ],
        ),
        'empty pattern': minimalFile(
          rules: [
            rule({'pattern': '  '}),
          ],
        ),
        'category not in the file': minimalFile(
          rules: [
            rule({'categoryId': 2}),
          ],
        ),
        'flag of the wrong type': minimalFile(
          rules: [
            rule({'isActive': 'yes'}),
          ],
        ),
        'amount that is not a number': minimalFile(
          rules: [
            rule({'amountMin': '5'}),
          ],
        ),
        'account without id or name': minimalFile(
          rules: [
            rule({'account': <String, Object?>{}}),
          ],
        ),
        'rule that is not an object': {
          ...minimalFile(),
          'rules': ['x'],
        },
        'unknown category type': minimalFile(
          categories: [
            category({'type': 'luxury'}),
          ],
          rules: [],
        ),
        'category id twice': minimalFile(
          categories: [
            category({}),
            category({'name': 'Kids'}),
          ],
          rules: [],
        ),
        'seeded key twice': minimalFile(
          categories: [
            category({'key': 'travel'}),
            category({'id': 2, 'key': 'travel'}),
          ],
          rules: [],
        ),
        'empty category name': minimalFile(
          categories: [
            category({'name': ' '}),
          ],
          rules: [],
        ),
        'category name too long': minimalFile(
          categories: [
            category({'name': 'x' * 101}),
          ],
          rules: [],
        ),
        'categories missing': {...minimalFile()}..remove('categories'),
      };
      for (final MapEntry(key: what, value: json) in broken.entries) {
        expect(() => RuleTransferService.parse(fileBytes(json)), problem(RuleFileProblem.invalidContent), reason: what);
      }
    });
  });
}
