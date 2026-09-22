import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('RuleService');

/// The subset of a transaction a rule is evaluated against. Decoupled from
/// the Drift row so previews can run on not-yet-inserted rows (import).
class RuleInput {
  final int accountId;
  final double amount;
  final String description;
  final String? descriptionFull;
  final String? merchantKey;
  final BankEntryKind? entryKind;

  const RuleInput({
    required this.accountId,
    required this.amount,
    required this.description,
    this.descriptionFull,
    this.merchantKey,
    this.entryKind,
  });

  factory RuleInput.of(Transaction t) => RuleInput(
    accountId: t.accountId,
    amount: t.amount,
    description: t.description,
    descriptionFull: t.descriptionFull,
    merchantKey: t.merchantKey,
    entryKind: t.entryKind,
  );

  String get haystack => (descriptionFull == null || descriptionFull!.isEmpty)
      ? description.toLowerCase()
      : '${description.toLowerCase()} ${descriptionFull!.toLowerCase()}';
}

/// A compiled, evaluation-ready rule. Compile once per classification pass —
/// regexes are parsed here, never per row.
class CompiledRule {
  final AutoCategorizationRule rule;
  final String _pattern;
  final RegExp? _regex;
  final bool _regexInvalid;

  CompiledRule._(this.rule, this._pattern, this._regex, this._regexInvalid);

  factory CompiledRule(AutoCategorizationRule rule) {
    RegExp? re;
    var invalid = false;
    if (rule.matchType == RuleMatchType.regex) {
      try {
        re = RegExp(rule.pattern, caseSensitive: false);
      } on FormatException {
        invalid = true;
        _log.warning('rule ${rule.id}: invalid regex "${rule.pattern}" — never matches');
      }
    }
    return CompiledRule._(rule, RuleService.normalizePattern(rule.matchType, rule.pattern), re, invalid);
  }

  int get categoryId => rule.categoryId;

  bool matches(RuleInput t) {
    final r = rule;
    if (r.accountId != null && r.accountId != t.accountId) return false;
    switch (r.direction) {
      case RuleDirection.inflow:
        if (t.amount <= 0) return false;
      case RuleDirection.outflow:
        if (t.amount >= 0) return false;
      case RuleDirection.any:
        break;
    }
    final abs = t.amount.abs();
    if (r.amountMin != null && abs < r.amountMin!) return false;
    if (r.amountMax != null && abs > r.amountMax!) return false;

    switch (r.matchType) {
      case RuleMatchType.merchantKey:
        return t.merchantKey != null && t.merchantKey == _pattern;
      case RuleMatchType.entryKind:
        return t.entryKind != null && t.entryKind!.name == _pattern;
      case RuleMatchType.contains:
        return _pattern.isNotEmpty && t.haystack.contains(_pattern);
      case RuleMatchType.regex:
        if (_regexInvalid || _regex == null) return false;
        return _regex.hasMatch(t.haystack);
    }
  }
}

class RuleService {
  final AppDatabase _db;
  RuleService(this._db);

  /// Canonical stored/compared form of a pattern for each match type.
  static String normalizePattern(RuleMatchType type, String raw) => switch (type) {
    RuleMatchType.merchantKey => raw.trim().toUpperCase(),
    RuleMatchType.contains => raw.trim().toLowerCase(),
    RuleMatchType.regex => raw.trim(),
    RuleMatchType.entryKind => raw.trim(),
  };

  /// True when [raw] is a usable pattern for [type] (non-empty, compilable,
  /// known entry kind).
  static bool isValidPattern(RuleMatchType type, String raw) {
    final p = raw.trim();
    if (p.isEmpty) return false;
    switch (type) {
      case RuleMatchType.regex:
        try {
          RegExp(p);
          return true;
        } on FormatException {
          return false;
        }
      case RuleMatchType.entryKind:
        return BankEntryKind.values.any((k) => k.name == p);
      case RuleMatchType.merchantKey:
      case RuleMatchType.contains:
        return true;
    }
  }

  SimpleSelectStatement<$AutoCategorizationRulesTable, AutoCategorizationRule> _ordered({bool activeOnly = false}) {
    final q = _db.select(_db.autoCategorizationRules);
    if (activeOnly) q.where((r) => r.isActive.equals(true));
    q.orderBy([(r) => OrderingTerm.asc(r.priority), (r) => OrderingTerm.asc(r.id)]);
    return q;
  }

  /// All rules in evaluation order (priority asc, then id asc).
  Stream<List<AutoCategorizationRule>> watchAll() => _ordered().watch();

  Future<List<AutoCategorizationRule>> getAll() => _ordered().get();

  Future<List<AutoCategorizationRule>> getActive() => _ordered(activeOnly: true).get();

  Future<List<CompiledRule>> compileActive() async => (await getActive()).map(CompiledRule.new).toList();

  Future<AutoCategorizationRule?> getById(int id) => (_db.select(_db.autoCategorizationRules)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// An existing rule with the same match type, pattern, category and scope,
  /// if any — creating it again would be a no-op duplicate.
  Future<AutoCategorizationRule?> findEquivalent({
    required RuleMatchType matchType,
    required String pattern,
    required int categoryId,
    int? accountId,
    RuleDirection direction = RuleDirection.any,
    double? amountMin,
    double? amountMax,
  }) async {
    final p = normalizePattern(matchType, pattern);
    final candidates = await (_db.select(
      _db.autoCategorizationRules,
    )..where((r) => r.matchType.equals(matchType.name) & r.pattern.equals(p) & r.categoryId.equals(categoryId))).get();
    for (final r in candidates) {
      if (r.accountId == accountId && r.direction == direction && r.amountMin == amountMin && r.amountMax == amountMax) {
        return r;
      }
    }
    return null;
  }

  /// Create a rule. New rules go LAST in evaluation order unless [priority]
  /// is given (lower = evaluated first). Creating an exact duplicate of an
  /// existing rule returns that rule's id instead (re-activating it).
  Future<int> create({
    required RuleMatchType matchType,
    required String pattern,
    required int categoryId,
    int? accountId,
    RuleDirection direction = RuleDirection.any,
    double? amountMin,
    double? amountMax,
    int? priority,
    bool isActive = true,
  }) async {
    if (!isValidPattern(matchType, pattern)) {
      throw ArgumentError.value(pattern, 'pattern', 'invalid for ${matchType.name}');
    }
    final existing = await findEquivalent(
      matchType: matchType,
      pattern: pattern,
      categoryId: categoryId,
      accountId: accountId,
      direction: direction,
      amountMin: amountMin,
      amountMax: amountMax,
    );
    if (existing != null) {
      if (!existing.isActive && isActive) await setActive(existing.id, true);
      _log.info('create: reusing equivalent rule ${existing.id} (${matchType.name}="$pattern")');
      return existing.id;
    }
    final p = priority ?? await _nextPriority();
    final id = await _db
        .into(_db.autoCategorizationRules)
        .insert(
          AutoCategorizationRulesCompanion.insert(
            pattern: normalizePattern(matchType, pattern),
            categoryId: categoryId,
            matchType: Value(matchType),
            accountId: Value(accountId),
            direction: Value(direction),
            amountMin: Value(amountMin),
            amountMax: Value(amountMax),
            priority: Value(p),
            isActive: Value(isActive),
          ),
        );
    _log.info('create: id=$id ${matchType.name}="$pattern" → category $categoryId');
    return id;
  }

  Future<int> _nextPriority() async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(priority), -1) AS m FROM auto_categorization_rules',
          readsFrom: {_db.autoCategorizationRules},
        )
        .getSingle();
    return row.read<int>('m') + 1;
  }

  Future<bool> update(int id, AutoCategorizationRulesCompanion companion) async {
    if (companion.pattern.present || companion.matchType.present) {
      final current = await getById(id);
      if (current == null) return false;
      final type = companion.matchType.present ? companion.matchType.value : current.matchType;
      final raw = companion.pattern.present ? companion.pattern.value : current.pattern;
      if (!isValidPattern(type, raw)) throw ArgumentError.value(raw, 'pattern', 'invalid for ${type.name}');
      companion = companion.copyWith(pattern: Value(normalizePattern(type, raw)));
    }
    final n = await (_db.update(_db.autoCategorizationRules)..where((r) => r.id.equals(id))).write(companion);
    return n > 0;
  }

  Future<bool> setActive(int id, bool active) => update(id, AutoCategorizationRulesCompanion(isActive: Value(active)));

  Future<int> delete(int id) async {
    _log.info('delete: id=$id');
    return (_db.delete(_db.autoCategorizationRules)..where((r) => r.id.equals(id))).go();
  }

  /// Persist a new evaluation order: [ids] first-to-last.
  Future<void> reorder(List<int> ids) async {
    await _db.transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await (_db.update(_db.autoCategorizationRules)..where((r) => r.id.equals(ids[i]))).write(
          AutoCategorizationRulesCompanion(priority: Value(i)),
        );
      }
    });
  }
}
