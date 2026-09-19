import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/utils/amount_parser.dart' as amt;
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('StoredMetadataRepair');

/// AppConfigs key: version of the stored-number normalization already applied
/// to this database. Bump [kRawMetadataLocaleVersion] to run it again.
const kRawMetadataLocaleVersionKey = 'RAW_METADATA_LOCALE_VERSION';
const int kRawMetadataLocaleVersion = 1;

/// Outcome for one account.
class AccountRepairReport {
  final int accountId;
  final String? accountName;
  final String targetLocale;
  final int rewritten;
  final int consistent;
  final List<int> unresolvedIds;
  final bool localePersisted;

  const AccountRepairReport({
    required this.accountId,
    required this.accountName,
    required this.targetLocale,
    required this.rewritten,
    required this.consistent,
    required this.unresolvedIds,
    required this.localePersisted,
  });

  @override
  String toString() =>
      'account $accountId (${accountName ?? '?'}): locale=$targetLocale rewritten=$rewritten consistent=$consistent unresolved=${unresolvedIds.length}';
}

class RepairReport {
  final List<AccountRepairReport> accounts;
  final bool dryRun;
  const RepairReport(this.accounts, {required this.dryRun});
  int get rewritten => accounts.fold(0, (s, a) => s + a.rewritten);
  int get unresolved => accounts.fold(0, (s, a) => s + a.unresolvedIds.length);
}

/// Normalizes the number spelling of the statement cells stored in
/// `transactions.raw_metadata` so every row of an account parses under the
/// account's saved number locale.
///
/// Why: XLSX numeric cells have no text of their own; the app stringified
/// them differently across its own versions (`3674.52` vs `6,95`), so one
/// account can hold both spellings and cannot be re-read with a single
/// locale. Recovery is exact, never a guess: a cell is rewritten only when
/// re-parsing it reproduces the row's stored `amount` (and `balance_after`,
/// when mapped) to the cent through the account's saved amount mapping —
/// the very numbers those cells produced at import time. Rows reproducing
/// under no spelling are left untouched and reported.
///
/// Scope: only the cells the saved mapping reads as numbers (amount column,
/// formula terms, balance-diff column, balanceAfter). Other columns are
/// never modified. Runs once per database (see [kRawMetadataLocaleVersion]).
class StoredMetadataRepair {
  final AppDatabase _db;
  StoredMetadataRepair(this._db);

  /// Two separator families cover every supported locale.
  static const _families = ['en_US', 'it_IT'];

  /// Repair every account with imported rows. [appLocale] is the target for
  /// accounts whose config has no saved locale (it is then persisted).
  /// [dryRun] computes the report without writing.
  Future<RepairReport> run({required String appLocale, bool dryRun = false}) async {
    final configs = await (_db.select(_db.importConfigs)..where((c) => c.scope.equals('transaction') & c.accountId.isNotNull())).get();
    final accounts = {for (final a in await _db.select(_db.accounts).get()) a.id: a.name};
    final reports = <AccountRepairReport>[];
    for (final cfg in configs) {
      final accountId = cfg.accountId!;
      if (!accounts.containsKey(accountId)) continue; // orphan config
      final r = await _repairAccount(cfg, accounts[accountId], appLocale: appLocale, dryRun: dryRun);
      if (r != null) {
        reports.add(r);
        _log.info('${dryRun ? '[dry-run] ' : ''}$r');
      }
    }
    return RepairReport(reports, dryRun: dryRun);
  }

  /// Run once per database, gated by [kRawMetadataLocaleVersionKey].
  Future<RepairReport?> runIfNeeded({required String appLocale}) async {
    final row = await (_db.select(_db.appConfigs)..where((c) => c.key.equals(kRawMetadataLocaleVersionKey))).getSingleOrNull();
    if ((int.tryParse(row?.value ?? '') ?? 0) >= kRawMetadataLocaleVersion) return null;
    final report = await run(appLocale: appLocale);
    await _db
        .into(_db.appConfigs)
        .insertOnConflictUpdate(
          AppConfigsCompanion.insert(
            key: kRawMetadataLocaleVersionKey,
            value: kRawMetadataLocaleVersion.toString(),
            description: const Value('Stored statement numbers normalized to each account\'s saved number locale'),
          ),
        );
    _log.info('stored-number normalization v$kRawMetadataLocaleVersion: rewritten=${report.rewritten} unresolved=${report.unresolved}');
    return report;
  }

  Future<AccountRepairReport?> _repairAccount(ImportConfig cfg, String? accountName, {required String appLocale, required bool dryRun}) async {
    final accountId = cfg.accountId!;
    final mappings = jsonDecode(cfg.mappingsJson) as Map<String, dynamic>;
    final formula = (jsonDecode(cfg.formulaJson) as List<dynamic>).cast<Map<String, dynamic>>();
    final numeric = _numericColumns(mappings, formula);
    if (numeric.isEmpty) return null;

    final rows =
        await (_db.select(_db.transactions)
              ..where((t) => t.accountId.equals(accountId) & t.rawMetadata.isNotNull())
              ..orderBy([(t) => OrderingTerm.asc(t.operationDate), (t) => OrderingTerm.asc(t.id)]))
            .get();
    if (rows.isEmpty) return null;

    final balanceDiffCol = mappings['__balanceDiffColumn'] as String?;
    final balanceMode = (mappings['__balanceMode'] as String?) ?? 'cumulative';
    final balanceCol = mappings['balanceAfter'] as String?;

    // Pass 1 — for every row, which separator families reproduce the stored
    // amount, and the values they parse. Balance-diff amounts depend on the
    // previous row's parsed balance, carried per family.
    final metas = <int, Map<String, dynamic>>{};
    final matches = <int, Map<String, Map<String, double>>>{}; // id → family → parsed cells
    final prevBalance = <String, double?>{for (final f in _families) f: null};
    for (final t in rows) {
      final decoded = jsonDecode(t.rawMetadata!);
      if (decoded is! Map) continue;
      final meta = Map<String, dynamic>.from(decoded);
      metas[t.id] = meta;
      final rowMatches = <String, Map<String, double>>{};
      for (final family in _families) {
        final values = <String, double>{};
        var ok = true;
        for (final col in numeric) {
          final raw = meta[col]?.toString() ?? '';
          if (raw.trim().isEmpty) continue;
          final v = amt.tryParseAmount(raw, locale: family);
          if (v == null) {
            ok = false;
            break;
          }
          values[col] = v;
        }
        if (!ok) continue;
        final amounts = _amountsFor(mappings, formula, balanceDiffCol, values, prevBalance[family]);
        if (!amounts.any((a) => (a - t.amount).abs() <= 0.005)) continue;
        if (balanceMode == 'column' && balanceCol != null && values.containsKey(balanceCol) && t.balanceAfter != null) {
          if ((values[balanceCol]! - t.balanceAfter!).abs() > 0.005) continue;
        }
        rowMatches[family] = values;
      }
      matches[t.id] = rowMatches;
      if (balanceDiffCol != null) {
        for (final family in _families) {
          final b = amt.tryParseAmount(meta[balanceDiffCol]?.toString() ?? '', locale: family);
          if (b != null) prevBalance[family] = b;
        }
      }
    }

    // Target spelling: the saved locale; else the single format the whole
    // account already reproduces under (original text kept, nothing
    // rewritten); else — a genuinely mixed account — the app locale.
    final target = cfg.numberLocale ?? _uniformFamily(matches.values, appLocale) ?? appLocale;

    // Pass 2 — rewrite every scoped cell of resolved rows in the target spelling.
    var rewritten = 0, consistent = 0;
    final unresolved = <int>[];
    final updates = <int, String>{};
    for (final t in rows) {
      final rowMatches = matches[t.id];
      if (rowMatches == null) continue;
      if (rowMatches.isEmpty) {
        unresolved.add(t.id);
        continue;
      }
      final values = rowMatches[_familyOf(target)] ?? rowMatches.values.first;
      final meta = metas[t.id]!;
      var changed = false;
      for (final e in values.entries) {
        final existing = meta[e.key]?.toString() ?? '';
        final asIs = amt.tryParseAmount(existing, locale: target);
        if (asIs != null && (asIs - e.value).abs() <= 0.005) continue; // original text already reads right
        meta[e.key] = amt.formatAmountLossless(e.value, locale: target);
        changed = true;
      }
      if (changed) {
        rewritten++;
        updates[t.id] = jsonEncode(meta);
      } else {
        consistent++;
      }
    }

    final persistLocale = cfg.numberLocale != target;
    if (!dryRun) {
      await _db.transaction(() async {
        for (final e in updates.entries) {
          await (_db.update(_db.transactions)..where((t) => t.id.equals(e.key))).write(
            TransactionsCompanion(rawMetadata: Value(e.value)),
          );
        }
        if (persistLocale) {
          await (_db.update(_db.importConfigs)..where((c) => c.id.equals(cfg.id))).write(
            ImportConfigsCompanion(numberLocale: Value(target), updatedAt: Value(DateTime.now())),
          );
        }
      });
    }
    return AccountRepairReport(
      accountId: accountId,
      accountName: accountName,
      targetLocale: target,
      rewritten: rewritten,
      consistent: consistent,
      unresolvedIds: unresolved,
      localePersisted: persistLocale && !dryRun,
    );
  }

  /// The locale to keep when every row already reproduces under one format:
  /// the app locale if its family is uniform, else the uniform family. Null
  /// when the account is mixed.
  static String? _uniformFamily(Iterable<Map<String, Map<String, double>>> rowMatches, String appLocale) {
    if (rowMatches.isEmpty) return null;
    final uniform = _families.where((f) => rowMatches.every((m) => m.containsKey(f))).toList();
    if (uniform.isEmpty) return null;
    return uniform.contains(_familyOf(appLocale)) ? appLocale : uniform.first;
  }

  /// Separator family of a locale tag (dot-decimal vs comma-decimal).
  static String _familyOf(String locale) => amt.formatAmountLossless(1.5, locale: locale).contains(',') ? 'it_IT' : 'en_US';

  /// Columns the saved mapping reads as numbers.
  static Set<String> _numericColumns(Map<String, dynamic> mappings, List<Map<String, dynamic>> formula) {
    final cols = <String>{};
    if (mappings['amount'] is String) cols.add(mappings['amount'] as String);
    for (final term in formula) {
      if (term['sourceColumn'] is String) cols.add(term['sourceColumn'] as String);
    }
    if (mappings['__balanceDiffColumn'] is String) cols.add(mappings['__balanceDiffColumn'] as String);
    if (mappings['balanceAfter'] is String) cols.add(mappings['balanceAfter'] as String);
    return cols;
  }

  /// The amounts the saved mapping can yield from parsed cell [values] —
  /// usually one; the first balance-diff row admits both historical rules
  /// (0, or the balance itself as the opening deposit). Empty when it cannot
  /// be computed (missing cells).
  static List<double> _amountsFor(
    Map<String, dynamic> mappings,
    List<Map<String, dynamic>> formula,
    String? balanceDiffCol,
    Map<String, double> values,
    double? prevBalance,
  ) {
    if (balanceDiffCol != null) {
      final b = values[balanceDiffCol];
      if (b == null) return const [];
      return prevBalance == null ? [0.0, b] : [b - prevBalance];
    }
    if (formula.isNotEmpty) {
      var sum = 0.0;
      for (final term in formula) {
        final v = values[term['sourceColumn']];
        if (v == null) continue; // empty cell contributes nothing, as in the importer
        sum += (term['operator'] == '-') ? -v : v;
      }
      return [sum];
    }
    final col = mappings['amount'];
    final v = col is String ? values[col] : null;
    return v == null ? const [] : [v];
  }
}
