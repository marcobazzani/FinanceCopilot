import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/classification/description_normalizer.dart' show normalizerVersion;
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/utils/formatters.dart' show formatYmd;
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('RuleTransferService');

/// Why a rules file cannot be imported. The UI words each one; the
/// exception's [RuleFileException.detail] only goes to the log.
enum RuleFileProblem {
  /// Not JSON, or JSON that is not a rules export.
  notRulesFile,

  /// Written in a format version this app does not know yet.
  newerVersion,

  /// Its merchant rules spell merchant keys as another app version builds
  /// them: here they would never match a transaction.
  normalizerMismatch,

  /// A rules export whose content does not hold together (an unknown value,
  /// a rule pointing at no category, a field of the wrong type…).
  invalidContent,
}

class RuleFileException implements Exception {
  final RuleFileProblem problem;
  final String detail;
  const RuleFileException(this.problem, this.detail);

  @override
  String toString() => 'RuleFileException(${problem.name}): $detail';
}

/// A category as a rules file carries it. [id] only links the file's rules to
/// it: ids differ from one database to another.
class RuleFileCategory {
  final int id;

  /// The seeded default's stable key (display name from l10n), null for a
  /// category the user created or renamed.
  final String? key;
  final String name;
  final CategoryType type;
  final String? icon;
  final String? color;
  final bool isEssential;
  final bool isArchived;

  const RuleFileCategory({
    required this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isEssential,
    required this.isArchived,
  });
}

/// The account a rule is limited to, by name: account ids differ from one
/// database to another. [name] is null when the account was deleted on the
/// exporting device; [id] is that device's id, used only to tell apart two
/// accounts of the same name.
class RuleFileAccount {
  final int? id;
  final String? name;
  const RuleFileAccount({required this.id, required this.name});

  /// How the rules list labels it ([name], else `#id`).
  String get label => name ?? '#$id';
}

/// A rule as a rules file carries it, its [pattern] already in stored form.
class RuleFileRule {
  final RuleMatchType matchType;
  final String pattern;

  /// The [RuleFileCategory.id] of its category.
  final int categoryId;
  final RuleDirection direction;
  final double? amountMin;
  final double? amountMax;
  final bool isActive;

  /// Null: the rule applies to every account.
  final RuleFileAccount? account;

  const RuleFileRule({
    required this.matchType,
    required this.pattern,
    required this.categoryId,
    required this.direction,
    required this.amountMin,
    required this.amountMax,
    required this.isActive,
    required this.account,
  });
}

/// A validated rules file: [categories] in display order, [rules] in
/// evaluation order.
class RuleFile {
  final List<RuleFileCategory> categories;
  final List<RuleFileRule> rules;
  const RuleFile({required this.categories, required this.rules});
}

/// What an import did.
class RuleImportResult {
  final int rulesImported;

  /// Rules this device had before, all replaced.
  final int rulesReplaced;
  final int categoriesAdded;

  /// Rules left out because their account is not on this device; never
  /// imported as rules for every account.
  final int rulesSkipped;

  /// The labels of those accounts ([RuleFileAccount.label]).
  final List<String> missingAccounts;

  const RuleImportResult({
    required this.rulesImported,
    required this.rulesReplaced,
    required this.categoriesAdded,
    required this.rulesSkipped,
    required this.missingAccounts,
  });
}

/// Export and import of the classifier setup (categories and rules) as a
/// JSON file, so the rules built on one database can be moved to another.
///
/// Categories are matched across databases by their seeded key, else by
/// name and type; accounts by name. Importing replaces this device's rules
/// with the file's, adds or updates the file's categories and keeps every
/// other category (transactions point at them).
class RuleTransferService {
  static const formatId = 'FinanceCopilot.classifierRules';
  static const formatVersion = 1;

  /// The longest category name the database stores.
  static const _maxCategoryName = 100;

  final AppDatabase _db;
  RuleTransferService(this._db);

  /// The file name an export made on [day] is offered under.
  static String fileNameFor(DateTime day) => 'FinanceCopilot-rules-${formatYmd(day)}.json';

  /// Every category (archived ones included) in display order and every rule
  /// in evaluation order, as the JSON a rules file holds, with how many of
  /// each it contains. [now] stamps the file (informational only).
  Future<({String json, int rules, int categories})> exportJson({DateTime? now}) async {
    final categories = await CategoryService(_db).getAll(includeArchived: true);
    final rules = await RuleService(_db).getAll();
    final accountNames = {for (final a in await _db.select(_db.accounts).get()) a.id: a.name};
    final data = <String, Object?>{
      'format': formatId,
      'version': formatVersion,
      'normalizerVersion': normalizerVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'categories': [
        for (final c in categories)
          <String, Object?>{
            'id': c.id,
            'key': c.key,
            'name': c.name,
            'type': c.type.name,
            'icon': c.icon,
            'color': c.color,
            'isEssential': c.isEssential,
            'isArchived': c.isArchived,
          },
      ],
      'rules': [
        for (final r in rules)
          <String, Object?>{
            'matchType': r.matchType.name,
            'pattern': r.pattern,
            'categoryId': r.categoryId,
            'direction': r.direction.name,
            'amountMin': r.amountMin,
            'amountMax': r.amountMax,
            'isActive': r.isActive,
            'account': r.accountId == null ? null : <String, Object?>{'id': r.accountId, 'name': accountNames[r.accountId]},
          },
      ],
    };
    _log.info('export: ${rules.length} rules, ${categories.length} categories');
    return (json: const JsonEncoder.withIndent('  ').convert(data), rules: rules.length, categories: categories.length);
  }

  /// Reads and validates a rules file. Throws [RuleFileException] when it
  /// cannot be imported as a whole: nothing is ever imported in part.
  static RuleFile parse(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw RuleFileException(RuleFileProblem.notRulesFile, 'not UTF-8 JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != formatId) {
      throw const RuleFileException(RuleFileProblem.notRulesFile, 'no "$formatId" format marker');
    }
    final version = decoded['version'];
    if (version is! int || version < 1) throw RuleFileException(RuleFileProblem.invalidContent, 'version: $version');
    if (version > formatVersion) throw RuleFileException(RuleFileProblem.newerVersion, 'version $version, this app reads up to $formatVersion');

    final categories = <RuleFileCategory>[];
    final ids = <int>{};
    final keys = <String>{};
    for (final (i, raw) in _list(decoded, 'categories', 'file').indexed) {
      final where = 'categories[$i]';
      final m = _map(raw, where);
      final id = _field<int>(m, 'id', where);
      if (!ids.add(id)) throw RuleFileException(RuleFileProblem.invalidContent, '$where: id $id appears twice');
      final key = _field<String?>(m, 'key', where);
      if (key != null && !keys.add(key)) throw RuleFileException(RuleFileProblem.invalidContent, '$where: key "$key" appears twice');
      final name = _field<String>(m, 'name', where).trim();
      if (name.isEmpty || name.length > _maxCategoryName) {
        throw RuleFileException(RuleFileProblem.invalidContent, '$where: name must be 1-$_maxCategoryName characters');
      }
      categories.add(
        RuleFileCategory(
          id: id,
          key: key,
          name: name,
          type: _enum(CategoryType.values, _field<String>(m, 'type', where), '$where.type'),
          icon: _field<String?>(m, 'icon', where),
          color: _field<String?>(m, 'color', where),
          isEssential: _field<bool>(m, 'isEssential', where),
          isArchived: _field<bool>(m, 'isArchived', where),
        ),
      );
    }

    final rules = <RuleFileRule>[];
    for (final (i, raw) in _list(decoded, 'rules', 'file').indexed) {
      final where = 'rules[$i]';
      final m = _map(raw, where);
      final matchType = _enum(RuleMatchType.values, _field<String>(m, 'matchType', where), '$where.matchType');
      final pattern = _field<String>(m, 'pattern', where);
      if (!RuleService.isValidPattern(matchType, pattern)) {
        throw RuleFileException(RuleFileProblem.invalidContent, '$where: invalid ${matchType.name} pattern "$pattern"');
      }
      final categoryId = _field<int>(m, 'categoryId', where);
      if (!ids.contains(categoryId)) throw RuleFileException(RuleFileProblem.invalidContent, '$where: category $categoryId is not in the file');
      final account = m['account'];
      RuleFileAccount? scope;
      if (account != null) {
        final a = _map(account, '$where.account');
        scope = RuleFileAccount(id: _field<int?>(a, 'id', '$where.account'), name: _field<String?>(a, 'name', '$where.account'));
        if (scope.id == null && scope.name == null) {
          throw RuleFileException(RuleFileProblem.invalidContent, '$where.account: neither id nor name');
        }
      }
      rules.add(
        RuleFileRule(
          matchType: matchType,
          pattern: RuleService.normalizePattern(matchType, pattern),
          categoryId: categoryId,
          direction: _enum(RuleDirection.values, _field<String>(m, 'direction', where), '$where.direction'),
          amountMin: _field<num?>(m, 'amountMin', where)?.toDouble(),
          amountMax: _field<num?>(m, 'amountMax', where)?.toDouble(),
          isActive: _field<bool>(m, 'isActive', where),
          account: scope,
        ),
      );
    }

    // Merchant rules compare against keys built by the description
    // normalizer: from another normalizer version they would never match.
    if (rules.any((r) => r.matchType == RuleMatchType.merchantKey)) {
      final fileNormalizer = decoded['normalizerVersion'];
      if (fileNormalizer is! int) throw RuleFileException(RuleFileProblem.invalidContent, 'normalizerVersion: $fileNormalizer');
      if (fileNormalizer != normalizerVersion) {
        throw RuleFileException(
          RuleFileProblem.normalizerMismatch,
          'merchant keys of normalizer v$fileNormalizer, this app builds v$normalizerVersion',
        );
      }
    }
    return RuleFile(categories: categories, rules: rules);
  }

  /// Replaces this device's rules with [file]'s, in the file's order, after
  /// adding or updating the file's categories. One transaction: either all of
  /// it is applied or none.
  ///
  /// A category is the same one when it has the same seeded key, else (both
  /// without a key) the same name, case aside, and the same type. A match takes
  /// the file's type, icon, color, essential flag and archived state; the
  /// display order becomes the file's, this device's other categories after
  /// it. No category is deleted.
  ///
  /// A rule limited to an account is mapped to this device's account of the
  /// same name (two of the same name: the one with the file's id). Without
  /// one, the rule is left out and reported, never widened to every account.
  Future<RuleImportResult> importFile(RuleFile file) => _db.transaction(() async {
    final current = await CategoryService(_db).getAll(includeArchived: true);
    final byKey = {for (final c in current) ?c.key: c};
    final taken = <int>{};
    final idMap = <int, int>{};
    var added = 0;
    for (final fc in file.categories) {
      final match = fc.key != null
          ? byKey[fc.key]
          : current.where((c) => c.key == null && !taken.contains(c.id) && c.type == fc.type && _sameName(c.name, fc.name)).firstOrNull;
      final int id;
      if (match != null) {
        id = match.id;
        await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
          CategoriesCompanion(
            // A seeded category is shown by its key: its stored name stays.
            name: fc.key == null ? Value(fc.name) : const Value.absent(),
            type: Value(fc.type),
            icon: Value(fc.icon),
            color: Value(fc.color),
            isEssential: Value(fc.isEssential),
            isArchived: Value(fc.isArchived),
          ),
        );
      } else {
        id = await _db
            .into(_db.categories)
            .insert(
              CategoriesCompanion.insert(
                name: fc.name,
                type: fc.type,
                key: Value(fc.key),
                icon: Value(fc.icon),
                color: Value(fc.color),
                isEssential: Value(fc.isEssential),
                isArchived: Value(fc.isArchived),
              ),
            );
        added++;
      }
      idMap[fc.id] = id;
      taken.add(id);
    }
    final order = [
      for (final fc in file.categories) idMap[fc.id]!,
      for (final c in current)
        if (!taken.contains(c.id)) c.id,
    ];
    for (final (i, id) in order.indexed) {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(CategoriesCompanion(sortOrder: Value(i)));
    }

    final accounts = await _db.select(_db.accounts).get();
    final replaced = await _db.delete(_db.autoCategorizationRules).go();
    // A rule repeated in the file is created once, active if any copy is, as
    // RuleService.create does for an equivalent rule.
    final created = <String, ({int id, bool active})>{};
    final missing = <String>{};
    var skipped = 0;
    for (final r in file.rules) {
      int? accountId;
      if (r.account case final scope?) {
        accountId = _accountFor(scope, accounts);
        if (accountId == null) {
          skipped++;
          missing.add(scope.label);
          continue;
        }
      }
      final categoryId = idMap[r.categoryId]!;
      final signature = [r.matchType.name, r.pattern, categoryId, accountId, r.direction.name, r.amountMin, r.amountMax].join('\u0000');
      final same = created[signature];
      if (same != null) {
        if (r.isActive && !same.active) {
          await (_db.update(_db.autoCategorizationRules)..where((x) => x.id.equals(same.id))).write(
            const AutoCategorizationRulesCompanion(isActive: Value(true)),
          );
          created[signature] = (id: same.id, active: true);
        }
        continue;
      }
      final id = await _db
          .into(_db.autoCategorizationRules)
          .insert(
            AutoCategorizationRulesCompanion.insert(
              pattern: r.pattern,
              categoryId: categoryId,
              matchType: Value(r.matchType),
              accountId: Value(accountId),
              direction: Value(r.direction),
              amountMin: Value(r.amountMin),
              amountMax: Value(r.amountMax),
              priority: Value(created.length),
              isActive: Value(r.isActive),
            ),
          );
      created[signature] = (id: id, active: r.isActive);
    }
    _log.info(
      'import: replaced $replaced rules with ${created.length}; categories: ${file.categories.length} in the file, $added added; '
      'skipped $skipped rules (accounts not found: ${missing.join(', ')})',
    );
    return RuleImportResult(
      rulesImported: created.length,
      rulesReplaced: replaced,
      categoriesAdded: added,
      rulesSkipped: skipped,
      missingAccounts: missing.toList(),
    );
  });

  static bool _sameName(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

  static int? _accountFor(RuleFileAccount scope, List<Account> accounts) {
    final name = scope.name?.trim();
    if (name == null) return null;
    final same = accounts.where((a) => a.name.trim() == name).toList();
    if (same.length == 1) return same.single.id;
    return same.where((a) => a.id == scope.id).firstOrNull?.id;
  }

  static List<Object?> _list(Map<String, dynamic> m, String key, String where) {
    final v = m[key];
    if (v is List) return v;
    throw RuleFileException(RuleFileProblem.invalidContent, '$where.$key: expected a list, got ${v.runtimeType}');
  }

  static Map<String, dynamic> _map(Object? v, String where) {
    if (v is Map<String, dynamic>) return v;
    throw RuleFileException(RuleFileProblem.invalidContent, '$where: expected an object, got ${v.runtimeType}');
  }

  /// Field [key] of [m] as a [T]. A nullable [T] accepts a missing field.
  static T _field<T>(Map<String, dynamic> m, String key, String where) {
    final v = m[key];
    if (v is T) return v;
    throw RuleFileException(RuleFileProblem.invalidContent, '$where.$key: expected $T, got ${v.runtimeType}');
  }

  static E _enum<E extends Enum>(List<E> values, String name, String where) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw RuleFileException(RuleFileProblem.invalidContent, '$where: unknown value "$name"');
  }
}
