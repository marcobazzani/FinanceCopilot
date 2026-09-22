import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/description_normalizer.dart';
import 'package:finance_copilot/services/classification/ledger_roles.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart' show RateLookup;
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('TransactionClassifierService');

/// AppConfigs key holding the normalizer version the stored keys were built with.
const kNormalizerVersionKey = 'NORMALIZER_VERSION';

/// Outcome of one classifier pass.
class ClassifyResult {
  /// Rows that were candidates (in scope, not ledger-excluded and, unless
  /// overwriting, uncategorized).
  final int scanned;

  /// Rows whose category actually changed (set by a rule or cleared because
  /// the ledger now explains them).
  final int changed;
  final int viaRules;

  /// Rows in scope with a [LedgerRole] (transfer / no-op / adjustment /
  /// cancelled): never categorized, not counted anywhere else.
  final int excluded;

  /// Rows in scope still without a category after the pass (excluded rows
  /// are not counted).
  final int uncategorizedAfter;

  const ClassifyResult({
    required this.scanned,
    required this.changed,
    required this.viaRules,
    required this.excluded,
    required this.uncategorizedAfter,
  });

  static const empty = ClassifyResult(scanned: 0, changed: 0, viaRules: 0, excluded: 0, uncategorizedAfter: 0);

  @override
  String toString() => 'ClassifyResult(scanned=$scanned changed=$changed rules=$viaRules excluded=$excluded left=$uncategorizedAfter)';
}

/// Uncategorized transactions sharing one merchant key.
class MerchantGroup {
  final String merchantKey;
  final String? counterparty;
  final BankEntryKind? entryKind;
  final int count;

  /// Sum of |amount| per currency (mixed-currency groups are not summed).
  final Map<String, double> totalByCurrency;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<int> accountIds;

  /// The most recent transaction of the group — what the wizard shows.
  final int latestTransactionId;

  /// Sum of |amount| in base currency over the rows with a known FX rate
  /// (0 when the ledger was not valued). Rows without a rate are counted in
  /// [fxMissing] and contribute nothing — never a guessed rate.
  final double baseTotal;
  final int fxMissing;

  const MerchantGroup({
    required this.merchantKey,
    required this.counterparty,
    required this.entryKind,
    required this.count,
    required this.totalByCurrency,
    required this.firstDate,
    required this.lastDate,
    required this.accountIds,
    required this.latestTransactionId,
    this.baseTotal = 0,
    this.fxMissing = 0,
  });

  /// Total when the group is single-currency, else null.
  (String, double)? get singleCurrencyTotal => totalByCurrency.length == 1 ? (totalByCurrency.keys.first, totalByCurrency.values.first) : null;
}

class ClassificationProgress {
  /// Rows that take part in categorization (ledger-excluded rows are not in it).
  final int total;
  final int categorized;

  /// Rows with a [LedgerRole], reported for transparency.
  final int excluded;

  /// Money that takes part in categorization, as |amount| in [baseCurrency],
  /// and the part of it already categorized. Null when the ledger was not
  /// valued (no rate lookup given). Rows without an FX rate are excluded
  /// from both sums and counted in [fxExcluded].
  final double? totalAmount;
  final double? categorizedAmount;
  final int fxExcluded;
  final String? baseCurrency;

  const ClassificationProgress({
    required this.total,
    required this.categorized,
    this.excluded = 0,
    this.totalAmount,
    this.categorizedAmount,
    this.fxExcluded = 0,
    this.baseCurrency,
  });
  int get uncategorized => total - categorized;
  double? get uncategorizedAmount => totalAmount == null ? null : totalAmount! - categorizedAmount!;

  /// Progress is measured in money when the ledger is valued (what matters is
  /// how much of the spending is explained, not how many rows), in rows
  /// otherwise.
  double get fraction {
    final ta = totalAmount;
    if (ta != null) return ta == 0 ? 1.0 : (categorizedAmount! / ta).clamp(0.0, 1.0);
    return total == 0 ? 1.0 : categorized / total;
  }
}

/// A ledger snapshot plus the |amount| of every row in base currency.
/// `null` in [baseAbs] = no FX rate known for that row on its value date.
class LedgerValuation {
  final String baseCurrency;
  final Map<int, double?> baseAbs;
  const LedgerValuation(this.baseCurrency, this.baseAbs);
}

/// Match counts for a rule preview.
class RuleMatchCount {
  final int total;
  final int uncategorized;
  const RuleMatchCount({required this.total, required this.uncategorized});
}

/// One consistent read of the ledger: every transaction plus the structural
/// role the ledger assigns to some of them.
class LedgerSnapshot {
  final List<Transaction> transactions;
  final Map<int, LedgerRole> roles;
  const LedgerSnapshot(this.transactions, this.roles);

  bool isExcluded(Transaction t) => roles.containsKey(t.id);

  /// Rows that take part in categorization.
  Iterable<Transaction> get participating => transactions.where((t) => !roles.containsKey(t.id));
}

/// The single classifier. Categories on rows are the cached result of the
/// user's rules; this service recomputes them on demand over the whole
/// ledger. Rows the ledger already explains (see [LedgerRole]) never take
/// part. No provenance flags, no heuristics.
class TransactionClassifierService {
  final AppDatabase _db;
  final RuleService _rules;
  final ExtraordinaryEventService _events;

  TransactionClassifierService(this._db) : _rules = RuleService(_db), _events = ExtraordinaryEventService(_db);

  // ── Ledger snapshot ──

  Future<LedgerSnapshot> loadLedger() async {
    final all = await _db.select(_db.transactions).get();
    final adj = await _events.getAdjustmentInputs();
    return LedgerSnapshot(all, resolveLedgerRoles(transactions: all, adjustments: adj));
  }

  /// Re-emits a fresh [LedgerSnapshot] whenever transactions or anything the
  /// adjustment resolution depends on changes.
  ///
  /// The SQL text must be unique among the app's trigger streams: drift shares
  /// stream queries by their SQL, so a plain `SELECT 1` would be merged with
  /// `ExtraordinaryEventService.watchAdjustmentRevision()` and inherit its
  /// (transaction-less) table set.
  Stream<LedgerSnapshot> watchLedger() {
    return _db
        .customSelect(
          "SELECT 'ledger' AS trigger",
          readsFrom: {_db.transactions, _db.extraordinaryEvents, _db.extraordinaryEventEntries, _db.bufferTransactions},
        )
        .watch()
        .asyncMap((_) => loadLedger());
  }

  // ── Classification ──

  /// Apply all active rules (priority order, first match wins) to the rows
  /// that take part in categorization. Ledger-excluded rows are skipped and,
  /// if they still carry a category from before, cleared.
  ///
  /// [overwrite] = false: only rows without a category are touched.
  /// [overwrite] = true: rows matching a rule get that category even if they
  /// already had one; rows matching nothing keep whatever they have.
  Future<ClassifyResult> classifyAll({int? accountId, bool overwrite = false}) async {
    final rules = await _rules.compileActive();
    final ledger = await loadLedger();

    final byCategory = <int?, List<int>>{};
    var scanned = 0, viaRules = 0, excluded = 0, leftover = 0;
    for (final tx in ledger.transactions) {
      if (accountId != null && tx.accountId != accountId) continue;
      if (ledger.isExcluded(tx)) {
        excluded++;
        if (tx.categoryId != null) (byCategory[null] ??= []).add(tx.id);
        continue;
      }
      if (!overwrite && tx.categoryId != null) continue;
      scanned++;
      int? cat;
      final input = RuleInput.of(tx);
      for (final r in rules) {
        if (r.matches(input)) {
          cat = r.categoryId;
          break;
        }
      }
      if (cat == null) {
        if (tx.categoryId == null) leftover++;
        continue;
      }
      if (cat == tx.categoryId) continue;
      viaRules++;
      (byCategory[cat] ??= []).add(tx.id);
    }

    final changed = byCategory.values.fold<int>(0, (s, l) => s + l.length);
    if (changed > 0) {
      await _db.transaction(() async {
        for (final e in byCategory.entries) {
          for (final chunk in _chunks(e.value, 500)) {
            await (_db.update(_db.transactions)..where((t) => t.id.isIn(chunk))).write(
              TransactionsCompanion(categoryId: Value(e.key)),
            );
          }
        }
      });
    }
    final result = ClassifyResult(
      scanned: scanned,
      changed: changed,
      viaRules: viaRules,
      excluded: excluded,
      uncategorizedAfter: leftover,
    );
    _log.info('classifyAll(account=$accountId overwrite=$overwrite): $result');
    return result;
  }

  /// Set (or clear) the category on specific rows.
  Future<int> setCategory(Iterable<int> ids, int? categoryId) async {
    final list = ids.toList();
    if (list.isEmpty) return 0;
    var n = 0;
    await _db.transaction(() async {
      for (final chunk in _chunks(list, 500)) {
        n += await (_db.update(_db.transactions)..where((t) => t.id.isIn(chunk))).write(
          TransactionsCompanion(categoryId: Value(categoryId)),
        );
      }
    });
    return n;
  }

  /// Rows matched by [rule] among the participating rows (preview for the
  /// rule editor).
  Future<RuleMatchCount> countMatches(CompiledRule rule) async {
    final ledger = await loadLedger();
    var total = 0, unc = 0;
    for (final tx in ledger.participating) {
      if (!rule.matches(RuleInput.of(tx))) continue;
      total++;
      if (tx.categoryId == null) unc++;
    }
    return RuleMatchCount(total: total, uncategorized: unc);
  }

  // ── Progress & grouping (wizard) ──

  static ClassificationProgress progressOf(LedgerSnapshot ledger, {int? accountId, LedgerValuation? valuation}) {
    var total = 0, done = 0, excluded = 0, fxExcluded = 0;
    var totalAmount = 0.0, doneAmount = 0.0;
    for (final t in ledger.transactions) {
      if (accountId != null && t.accountId != accountId) continue;
      if (ledger.isExcluded(t)) {
        excluded++;
        continue;
      }
      total++;
      if (t.categoryId != null) done++;
      if (valuation != null) {
        final v = valuation.baseAbs[t.id];
        if (v == null) {
          fxExcluded++;
        } else {
          totalAmount += v;
          if (t.categoryId != null) doneAmount += v;
        }
      }
    }
    return ClassificationProgress(
      total: total,
      categorized: done,
      excluded: excluded,
      totalAmount: valuation == null ? null : totalAmount,
      categorizedAmount: valuation == null ? null : doneAmount,
      fxExcluded: fxExcluded,
      baseCurrency: valuation?.baseCurrency,
    );
  }

  /// Value every row of [ledger] in [baseCurrency] on its value date. Rows in
  /// the base currency need no rate; the others are looked up and, when no
  /// rate exists, recorded as null (excluded and counted by the consumers).
  static Future<LedgerValuation> valueLedger(LedgerSnapshot ledger, {required RateLookup rate, required String baseCurrency}) async {
    final out = <int, double?>{};
    for (final t in ledger.transactions) {
      if (t.currency == baseCurrency) {
        out[t.id] = t.amount.abs();
        continue;
      }
      final d = t.valueDate;
      final dayKey = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
      final r = await rate(t.currency, dayKey);
      out[t.id] = r == null ? null : t.amount.abs() * r;
    }
    return LedgerValuation(baseCurrency, out);
  }

  /// Ledger stream with a valuation attached, or without one when no rate
  /// lookup is given (row-count semantics).
  Stream<(LedgerSnapshot, LedgerValuation?)> _watchValued({RateLookup? rate, String? baseCurrency}) {
    if (rate == null || baseCurrency == null) return watchLedger().map((l) => (l, null));
    return watchLedger().asyncMap((l) async => (l, await valueLedger(l, rate: rate, baseCurrency: baseCurrency)));
  }

  Stream<ClassificationProgress> watchProgress({int? accountId, RateLookup? rate, String? baseCurrency}) =>
      _watchValued(rate: rate, baseCurrency: baseCurrency).map((v) => progressOf(v.$1, accountId: accountId, valuation: v.$2));

  Future<ClassificationProgress> progress({int? accountId, RateLookup? rate, String? baseCurrency}) async {
    final ledger = await loadLedger();
    final valuation = rate == null || baseCurrency == null ? null : await valueLedger(ledger, rate: rate, baseCurrency: baseCurrency);
    return progressOf(ledger, accountId: accountId, valuation: valuation);
  }

  /// Uncategorized, participating rows grouped by merchant key. With a
  /// [valuation]: the groups worth the most money come first (that is where
  /// a rule explains the most spending); without one, the biggest by count.
  static List<MerchantGroup> groupsOf(LedgerSnapshot ledger, {int? accountId, LedgerValuation? valuation}) {
    final acc = <String, _GroupAcc>{};
    for (final t in _uncategorizedIn(ledger, accountId: accountId)) {
      final key = t.merchantKey;
      if (key == null) continue;
      final g = acc[key] ??= _GroupAcc(key);
      g.count++;
      g.totals[t.currency] = (g.totals[t.currency] ?? 0) + t.amount.abs();
      if (valuation != null) {
        final v = valuation.baseAbs[t.id];
        if (v == null) {
          g.fxMissing++;
        } else {
          g.baseTotal += v;
        }
      }
      if (g.first == null || t.valueDate.isBefore(g.first!)) g.first = t.valueDate;
      if (g.last == null || t.valueDate.isAfter(g.last!)) g.last = t.valueDate;
      g.counterparty ??= t.counterparty;
      g.entryKind ??= t.entryKind;
      g.accountIds.add(t.accountId);
      if (g.latest == null || _newer(t, g.latest!)) g.latest = t;
    }
    return acc.values.map((g) => g.build()).toList()..sort((a, b) {
      if (valuation != null) {
        final v = b.baseTotal.compareTo(a.baseTotal);
        if (v != 0) return v;
      }
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.merchantKey.compareTo(b.merchantKey);
    });
  }

  Stream<List<MerchantGroup>> watchUncategorizedGroups({int? accountId, RateLookup? rate, String? baseCurrency}) =>
      _watchValued(rate: rate, baseCurrency: baseCurrency).map((v) => groupsOf(v.$1, accountId: accountId, valuation: v.$2));

  static Iterable<Transaction> _uncategorizedIn(LedgerSnapshot ledger, {int? accountId}) => ledger.participating.where(
    (t) => t.categoryId == null && (accountId == null || t.accountId == accountId),
  );

  static bool _newer(Transaction a, Transaction b) {
    final c = a.valueDate.compareTo(b.valueDate);
    return c != 0 ? c > 0 : a.id > b.id;
  }

  /// Uncategorized, participating rows of one group, newest first.
  Future<List<Transaction>> uncategorizedOf(String merchantKey, {int? accountId, int limit = 50}) async {
    final ledger = await loadLedger();
    final rows = _uncategorizedIn(ledger, accountId: accountId).where((t) => t.merchantKey == merchantKey).toList()
      ..sort((a, b) => _newer(a, b) ? -1 : 1);
    return rows.length > limit ? rows.sublist(0, limit) : rows;
  }

  /// Ids of all uncategorized, participating rows of one group.
  Future<List<int>> uncategorizedIdsOf(String merchantKey, {int? accountId}) async {
    final rows = await uncategorizedOf(merchantKey, accountId: accountId, limit: 1 << 30);
    return rows.map((t) => t.id).toList();
  }

  /// Ids of every uncategorized, participating row. The wizard snapshots this
  /// before and after a classifier run to know exactly which rows a new rule
  /// categorized (exact undo without provenance columns).
  Future<Set<int>> uncategorizedIds() async => _uncategorizedIn(await loadLedger()).map((t) => t.id).toSet();

  // ── Derived keys ──

  /// Compute the derived columns for one row (used by import and manual edits).
  static NormalizedEntry normalize({
    required String description,
    String? descriptionFull,
    String? rawMetadataJson,
    required double amount,
  }) {
    Map<String, dynamic>? meta;
    if (rawMetadataJson != null && rawMetadataJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMetadataJson);
        if (decoded is Map<String, dynamic>) meta = decoded;
      } on FormatException {
        meta = null;
      }
    }
    return normalizeDescription(
      description: description,
      descriptionFull: descriptionFull,
      rawMetadata: meta,
      inflow: amount > 0,
    );
  }

  /// Recompute `merchant_key` / `counterparty` / `entry_kind` when the
  /// normalizer version changed or when rows lack a key. Returns the number
  /// of rows rewritten. Safe to call on every startup.
  ///
  /// Merchant-key rules are the user's work and must survive a normalizer
  /// change: every rule whose pattern equals an OLD key is re-pointed at the
  /// NEW key(s) those same rows now carry (one rule per distinct new key).
  Future<int> recomputeKeysIfStale({bool force = false}) async {
    final row = await (_db.select(_db.appConfigs)..where((c) => c.key.equals(kNormalizerVersionKey))).getSingleOrNull();
    final stored = int.tryParse(row?.value ?? '');
    final versionChanged = stored != normalizerVersion;

    final List<Transaction> rows;
    if (force || versionChanged) {
      rows = await _db.select(_db.transactions).get();
    } else {
      rows = await (_db.select(_db.transactions)..where((t) => t.merchantKey.isNull())).get();
    }
    if (rows.isNotEmpty) {
      // old key → set of new keys its rows moved to.
      final moved = <String, Set<String>>{};
      await _db.transaction(() async {
        await _db.batch((b) {
          for (final tx in rows) {
            final n = normalize(
              description: tx.description,
              descriptionFull: tx.descriptionFull,
              rawMetadataJson: tx.rawMetadata,
              amount: tx.amount,
            );
            final old = tx.merchantKey;
            if (old != null && old != n.merchantKey) (moved[old] ??= {}).add(n.merchantKey);
            b.update(
              _db.transactions,
              TransactionsCompanion(
                merchantKey: Value(n.merchantKey),
                counterparty: Value(n.counterparty),
                entryKind: Value(n.entryKind),
              ),
              where: (t) => t.id.equals(tx.id),
            );
          }
        });
        if (moved.isNotEmpty) await _migrateMerchantRules(moved);
      });
      _log.info('recomputeKeysIfStale: rewrote ${rows.length} rows (versionChanged=$versionChanged force=$force)');
    }
    if (versionChanged) {
      await _db
          .into(_db.appConfigs)
          .insertOnConflictUpdate(
            AppConfigsCompanion.insert(
              key: kNormalizerVersionKey,
              value: normalizerVersion.toString(),
              description: const Value('Version of the description normalizer that built transaction merchant keys'),
            ),
          );
    }
    return rows.length;
  }

  /// Re-point merchant-key rules whose pattern was an old key. When the rows
  /// of one old key now split across several new keys, the first new key
  /// updates the rule in place and the others get a clone, so the rule keeps
  /// covering exactly the rows it covered before.
  Future<int> _migrateMerchantRules(Map<String, Set<String>> moved) async {
    final rules = await (_db.select(
      _db.autoCategorizationRules,
    )..where((r) => r.matchType.equals(RuleMatchType.merchantKey.name) & r.pattern.isIn(moved.keys.toList()))).get();
    var n = 0;
    for (final r in rules) {
      final targets = moved[r.pattern]!.toList()..sort();
      await (_db.update(_db.autoCategorizationRules)..where((x) => x.id.equals(r.id))).write(
        AutoCategorizationRulesCompanion(pattern: Value(targets.first)),
      );
      for (final extra in targets.skip(1)) {
        await _db
            .into(_db.autoCategorizationRules)
            .insert(
              AutoCategorizationRulesCompanion.insert(
                pattern: extra,
                categoryId: r.categoryId,
                matchType: Value(r.matchType),
                accountId: Value(r.accountId),
                direction: Value(r.direction),
                amountMin: Value(r.amountMin),
                amountMax: Value(r.amountMax),
                priority: Value(r.priority),
                isActive: Value(r.isActive),
              ),
            );
      }
      n++;
      _log.info('rule ${r.id}: merchant key "${r.pattern}" → ${targets.join(", ")}');
    }
    return n;
  }

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}

class _GroupAcc {
  final String key;
  int count = 0;
  double baseTotal = 0;
  int fxMissing = 0;
  final totals = <String, double>{};
  DateTime? first;
  DateTime? last;
  String? counterparty;
  BankEntryKind? entryKind;
  final accountIds = <int>{};
  Transaction? latest;
  _GroupAcc(this.key);

  MerchantGroup build() => MerchantGroup(
    merchantKey: key,
    counterparty: counterparty,
    entryKind: entryKind,
    count: count,
    totalByCurrency: totals,
    firstDate: first!,
    lastDate: last!,
    accountIds: accountIds,
    latestTransactionId: latest!.id,
    baseTotal: baseTotal,
    fxMissing: fxMissing,
  );
}
