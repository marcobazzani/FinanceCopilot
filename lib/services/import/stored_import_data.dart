// Tolerant readers of what an import stores: the settings saved next to the
// column mappings of an import config (`import_configs.mappings_json`, the
// hidden `__*` keys), its amount formula, and the raw statement cells kept on
// every imported row (`raw_metadata`).
//
// The app always writes these as they are read here, but a database can carry
// text of another shape (another app version, a hand edit, a merged backup).
// A value of an unexpected shape is logged and reported as unreadable — never
// thrown, and never replaced by a default that would read as a setting the
// user did not save.
import 'dart:convert';

import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('StoredImportData');

/// How an account's per-row running balance (`transactions.balance_after`) is
/// computed. Saved in its import config under
/// [SavedImportMappings.balanceModeKey]; each value's [name] is the string
/// stored there.
enum BalanceMode {
  /// No balance is computed: stored balances are left as they are.
  none,

  /// Running sum of every row's amount.
  cumulative,

  /// The bank's balance column ([BalanceSettings.balanceColumn]): a value-date
  /// running balance anchored on the bank's closing (see running_balance.dart).
  column,

  /// Running sum of the rows whose [BalanceSettings.filterColumn] value is
  /// included; the other rows never moved the balance and are cancelled.
  filtered;

  /// The mode of a saved config that stores none: cumulative, what the import
  /// wizard and the balance dialog start from and show for it. Both always
  /// store the mode they apply; no automatic recalculation reads a config
  /// that stores none ([SavedImportMappings.storesBalanceMode]). The
  /// number-format placeholder an import stores before the wizard saves its
  /// settings holds no settings at all and reads as no import config
  /// ([SavedImportMappings.isEmpty]).
  static const byDefault = cumulative;

  /// The mode stored as [raw]: [byDefault] when none is stored (null), null
  /// when [raw] is not one of the stored names — unreadable, never guessed.
  static BalanceMode? parse(Object? raw) {
    if (raw == null) return byDefault;
    for (final mode in values) {
      if (mode.name == raw) return mode;
    }
    return null;
  }
}

/// What a balance recalculation in [mode] reads from a saved import config.
class BalanceSettings {
  final BalanceMode mode;

  /// [BalanceMode.column]: the statement column holding the bank's balance
  /// (the `balanceAfter` mapping).
  final String? balanceColumn;

  /// [BalanceMode.filtered]: the statement column whose value decides whether
  /// a row moved the balance.
  final String? filterColumn;

  /// [BalanceMode.filtered]: the [filterColumn] values that moved the balance;
  /// empty = every value.
  final Set<String> filterInclude;

  const BalanceSettings(this.mode, {this.balanceColumn, this.filterColumn, this.filterInclude = const {}});
}

/// The mappings of a saved import config (`mappings_json`): target field →
/// source column, plus the hidden `__*` settings the wizard and the balance
/// dialog store next to them.
///
/// Every accessor tolerates a value of an unexpected shape: it is logged, its
/// key is added to [unreadable] and the accessor reports it as unreadable
/// (null) — distinct from an absent value.
class SavedImportMappings {
  static const balanceModeKey = '__balanceMode';
  static const balanceFilterColumnKey = '__balanceFilterColumn';
  static const balanceFilterIncludeKey = '__balanceFilterInclude';
  static const _balanceColumnKey = 'balanceAfter';

  /// The mappings as stored. Empty when [corrupt].
  final Map<String, dynamic> values;

  /// The stored text is not a JSON object: nothing could be read.
  final bool corrupt;

  /// Keys whose value had an unexpected shape (logged once each).
  final Set<String> unreadable = {};

  /// Mappings already in memory (e.g. the ones about to be saved).
  SavedImportMappings(this.values) : corrupt = false;

  SavedImportMappings._corrupt() : values = const {}, corrupt = true;

  /// Reads a stored `mappings_json`; text that is not a JSON object is logged
  /// and read as [corrupt].
  factory SavedImportMappings.decode(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return SavedImportMappings(decoded);
    } on FormatException {
      // Reported below.
    }
    _log.warning('saved import mappings are not a JSON object - no setting read from them: ${_excerpt(json)}');
    return SavedImportMappings._corrupt();
  }

  /// No settings at all — the number-format placeholder an import stores for
  /// an account before the wizard saves its settings (ImportService): it reads
  /// as no import config.
  bool get isEmpty => values.isEmpty && !corrupt;

  /// The text stored under [key]; null when absent, or unreadable when it is
  /// not text.
  String? text(String key) => _text(key).value;

  /// A `'true'` flag.
  bool flag(String key) => text(key) == 'true';

  /// The text stored under [key] when it is one of [allowed]; null when
  /// absent, or unreadable when it is any other value.
  String? choice(String key, List<String> allowed) {
    final value = text(key);
    if (value == null || allowed.contains(value)) return value;
    _unreadable(key, value);
    return null;
  }

  /// The values stored under [key] as a JSON-encoded list (what the app
  /// writes) or as a JSON list: text as it is, numbers and booleans as text.
  /// Empty when absent; null when unreadable.
  List<String>? textList(String key) => _textList(key).value;

  /// The JSON objects stored under [key] as a JSON-encoded list, each read by
  /// [fromJson]. Empty when absent; null when the list or one of them is
  /// unreadable — never a partial list.
  List<T>? objects<T>(String key, T Function(Map<String, dynamic> json) fromJson) {
    final raw = values[key];
    if (raw == null) return <T>[];
    try {
      final list = raw is String ? jsonDecode(raw) : raw;
      return [for (final item in list as List) fromJson(item as Map<String, dynamic>)];
    } catch (_) {
      _unreadable(key, raw);
      return null;
    }
  }

  /// The saved balance mode: [BalanceMode.byDefault] when none is stored
  /// ([storesBalanceMode]), null when unreadable (or the mappings are
  /// [corrupt]).
  BalanceMode? get balanceMode {
    if (corrupt) return null;
    final mode = BalanceMode.parse(values[balanceModeKey]);
    if (mode == null) _unreadable(balanceModeKey, values[balanceModeKey]);
    return mode;
  }

  /// Whether a balance mode is stored. A config an earlier app version saved
  /// may hold none: the import wizard and the balance dialog start it from
  /// [BalanceMode.byDefault], but no automatic recalculation runs for it —
  /// its balances are left as they are (TransactionService).
  bool get storesBalanceMode => values[balanceModeKey] != null;

  /// The saved balance settings; null when unreadable — the mode, or a
  /// setting the mode reads.
  BalanceSettings? get balance {
    final mode = balanceMode;
    return mode == null ? null : balanceFor(mode);
  }

  /// The settings [mode] reads from these mappings (the balance dialog applies
  /// the mode the user picks). Null when one of them is unreadable; settings
  /// [mode] does not read are not looked at.
  BalanceSettings? balanceFor(BalanceMode mode) {
    if (corrupt && mode != BalanceMode.none && mode != BalanceMode.cumulative) return null;
    switch (mode) {
      case BalanceMode.none || BalanceMode.cumulative:
        return BalanceSettings(mode);
      case BalanceMode.column:
        final column = _text(_balanceColumnKey);
        return column.readable ? BalanceSettings(mode, balanceColumn: column.value) : null;
      case BalanceMode.filtered:
        final column = _text(balanceFilterColumnKey);
        final include = _textList(balanceFilterIncludeKey);
        if (include case (readable: true, value: final values?) when column.readable) {
          return BalanceSettings(mode, filterColumn: column.value, filterInclude: values.toSet());
        }
        return null;
    }
  }

  /// The amount formula stored in an import config's `formula_json`: its terms,
  /// each `{'operator': '+' | '-', 'sourceColumn': column}`. Null (logged) when
  /// it is not a JSON list of such terms.
  static List<Map<String, String>>? formulaTerms(String json) {
    try {
      return [
        for (final term in jsonDecode(json) as List)
          {'operator': (term as Map)['operator'] as String, 'sourceColumn': term['sourceColumn'] as String},
      ];
    } catch (_) {
      _log.warning('saved amount formula is not a list of terms - not used: ${_excerpt(json)}');
      return null;
    }
  }

  /// A JSON list of texts stored in an import config column (e.g.
  /// `hash_columns_json`). Null (logged) when it is not one.
  static List<String>? textListOf(String json) {
    try {
      return [for (final v in jsonDecode(json) as List) v as String];
    } catch (_) {
      _log.warning('saved column list is not a JSON list of texts - not used: ${_excerpt(json)}');
      return null;
    }
  }

  ({bool readable, String? value}) _text(String key) {
    final raw = values[key];
    if (raw == null || raw is String) return (readable: true, value: raw as String?);
    _unreadable(key, raw);
    return (readable: false, value: null);
  }

  ({bool readable, List<String>? value}) _textList(String key) {
    final raw = values[key];
    if (raw == null || raw == '') return (readable: true, value: const <String>[]);
    Object? list = raw;
    if (raw is String) {
      try {
        list = jsonDecode(raw);
      } on FormatException {
        list = null;
      }
    }
    if (list is List && list.every((v) => v is String || v is num || v is bool)) {
      return (readable: true, value: [for (final v in list) v.toString()]);
    }
    _unreadable(key, raw);
    return (readable: false, value: null);
  }

  void _unreadable(String key, Object? raw) {
    if (unreadable.add(key)) _log.warning('saved import setting $key is unreadable - not used: ${_excerpt('$raw')}');
  }
}

/// The raw statement cells stored on an imported row (`raw_metadata` of a
/// transaction or an asset event): column → cell. Null when there are none —
/// no text, or a blank one — or (logged) when the text is not a JSON object:
/// the row is then read as one without statement data. The log line carries
/// none of the text: statement cells are amounts and balances.
Map<String, dynamic>? decodeRawMetadata(String? json) {
  if (json == null || json.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Reported below.
  }
  _log.warning('raw statement data is not a JSON object (${json.length} characters) - row read without it');
  return null;
}

/// A bounded excerpt of stored text for a log line.
String _excerpt(String text) => text.length <= 80 ? text : '${text.substring(0, 80)}…';
