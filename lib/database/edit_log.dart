import 'dart:convert';

/// The kinds of data a person edits, as the sync indicator lists them.
enum EditArea {
  accounts,
  transactions,
  intermediaries,
  assets,
  assetEvents,
  compositions,
  incomes,
  categories,
  rules,
  adjustments,
  pillars,
  portfolioModels,
  importSettings,
  settings,
  other,
}

enum EditKind { added, changed, deleted }

/// One kind of change to one area, e.g. accounts added.
typedef EditChange = (EditArea, EditKind);

/// The area each table's rows belong to. Every table is listed, provider data
/// included, so a new table needs a decision (a test checks it). A table
/// missing here still records its edits, under [EditArea.other].
const editAreaOfTable = <String, EditArea?>{
  'accounts': EditArea.accounts,
  'transactions': EditArea.transactions,
  'intermediaries': EditArea.intermediaries,
  'assets': EditArea.assets,
  'asset_snapshots': EditArea.assets,
  'asset_events': EditArea.assetEvents,
  'asset_compositions': EditArea.compositions,
  'incomes': EditArea.incomes,
  'categories': EditArea.categories,
  'auto_categorization_rules': EditArea.rules,
  // Reimbursements live in a buffer tied to their adjustment.
  'extraordinary_events': EditArea.adjustments,
  'extraordinary_event_entries': EditArea.adjustments,
  'buffers': EditArea.adjustments,
  'buffer_transactions': EditArea.adjustments,
  'pillars': EditArea.pillars,
  'pillar_assets': EditArea.pillars,
  'portfolio_models': EditArea.portfolioModels,
  'portfolio_model_items': EditArea.portfolioModels,
  'import_configs': EditArea.importSettings,
  'app_configs': EditArea.settings,
  'health_reimbursements': EditArea.other,
  // Provider data (market prices, also rebuilt from revalue events; exchange
  // rates): writing it is never a manual edit, whoever writes it.
  'market_prices': null,
  'exchange_rates': null,
};

/// The area a write to [table] edits; null for provider data, never an edit.
EditArea? editAreaOf(String table) => editAreaOfTable.containsKey(table) ? editAreaOfTable[table] : EditArea.other;

/// AppConfigs key of the [EditLog]. Written only by the manual-edit tracker.
const kManualEditLogKey = 'MANUAL_EDIT_LOG';

/// The manual edits recorded on a database: for each area and kind of change,
/// a token every such edit renews, and how many rows were edited in all.
/// Comparing a log with an earlier one of the same database tells which kinds
/// of change were made since; it travels with the data into every backup.
class EditLog {
  const EditLog({this.changes = 0, this.tokens = const {}});

  static const empty = EditLog();

  /// Rows edited by hand, in all.
  final int changes;

  /// The token of each kind of change made at least once.
  final Map<EditChange, String> tokens;

  /// The log stored as [json]; empty when there is none yet (nothing edited
  /// by hand since tracking began) or it cannot be read. Unknown areas and
  /// kinds (a newer app version) are left out.
  factory EditLog.decode(String? json) {
    if (json == null) return empty;
    final Object? raw;
    try {
      raw = jsonDecode(json);
    } on FormatException {
      return empty;
    }
    if (raw is! Map<String, Object?>) return empty;
    final tokens = <EditChange, String>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (value is! String) continue;
      if (_changeOfKey(key) case final change?) tokens[change] = value;
    }
    final n = raw[changesKey];
    return EditLog(changes: n is int ? n : 0, tokens: tokens);
  }

  /// JSON key of the row count.
  static const changesKey = 'n';

  /// JSON key of the token of [change].
  static String keyOf(EditChange change) => '${change.$1.name}.${change.$2.name}';

  static EditChange? _changeOfKey(String key) {
    final parts = key.split('.');
    if (parts.length != 2) return null;
    final area = EditArea.values.asNameMap()[parts[0]];
    final kind = EditKind.values.asNameMap()[parts[1]];
    return area == null || kind == null ? null : (area, kind);
  }

  String encode() => jsonEncode({changesKey: changes, for (final MapEntry(:key, :value) in tokens.entries) keyOf(key): value});

  /// The kinds of change made in this log since [base], an earlier log of the
  /// same data.
  Set<EditChange> editedSince(EditLog base) => {
    for (final MapEntry(:key, :value) in tokens.entries)
      if (base.tokens[key] != value) key,
  };

  @override
  bool operator ==(Object other) =>
      other is EditLog &&
      other.changes == changes &&
      other.tokens.length == tokens.length &&
      tokens.entries.every((e) => other.tokens[e.key] == e.value);

  @override
  int get hashCode => Object.hash(changes, Object.hashAllUnordered(tokens.entries.map((e) => Object.hash(e.key, e.value))));

  @override
  String toString() => 'EditLog(${encode()})';
}
