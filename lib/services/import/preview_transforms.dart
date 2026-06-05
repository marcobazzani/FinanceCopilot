import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('PreviewTransforms');

/// How a [RowFilter] compares a column's cell value against [value].
enum FilterOp { contains, notContains, equals, notEquals, matches, notMatches }

/// Whether a set of [RowFilter]s must all pass (and) or any pass (or).
enum FilterCombine { all, any }

/// A single row-level filter rule: keep or drop a row based on whether the
/// cell in [column] satisfies [op] against [value].
///
/// Mirrors the shell idiom `grep -e 'C/'` (keep matching) and
/// `egrep -v 'Totale'` (drop matching) but expressed per-column and
/// applied uniformly to any parsed source (CSV/XLSX/PDF/clipboard).
class RowFilter {
  final String column;
  final FilterOp op;
  final String value;

  const RowFilter({required this.column, required this.op, required this.value});

  /// True when [row] passes this single rule (i.e. should be kept).
  bool passes(Map<String, String> row) {
    final cell = row[column] ?? '';
    switch (op) {
      case FilterOp.contains:
        return cell.contains(value);
      case FilterOp.notContains:
        return !cell.contains(value);
      case FilterOp.equals:
        return cell == value;
      case FilterOp.notEquals:
        return cell != value;
      case FilterOp.matches:
        return _safeRegex(value)?.hasMatch(cell) ?? false;
      case FilterOp.notMatches:
        return !(_safeRegex(value)?.hasMatch(cell) ?? false);
    }
  }

  static RegExp? _safeRegex(String pattern) {
    try {
      return RegExp(pattern);
    } catch (e) {
      _log.warning('RowFilter: invalid regex "$pattern": $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {'column': column, 'op': op.name, 'value': value};

  static RowFilter fromJson(Map<String, dynamic> j) => RowFilter(
    column: j['column'] as String,
    op: FilterOp.values.firstWhere((o) => o.name == j['op'], orElse: () => FilterOp.contains),
    value: (j['value'] as String?) ?? '',
  );
}

/// A column-split rule: take [sourceColumn] and split each cell into new
/// columns named [newColumns], either by a delimiter (collapsing runs of
/// whitespace when [byRegex] is false and [delimiter] is empty/whitespace)
/// or by a capture regex.
///
/// Mirrors the shell idiom that splits `C/TFR mese 07/2021` into
/// type=`C/TFR`, freq=`mese`, period=`07/2021`.
class ColumnSplit {
  final String sourceColumn;
  final List<String> newColumns;

  /// When false: split on [delimiter]; an empty/whitespace delimiter means
  /// "split on runs of whitespace" (the common PDF/`pdftotext` case).
  /// When true: [pattern] is a regex; its capture groups fill [newColumns].
  final bool byRegex;
  final String delimiter;
  final String pattern;

  const ColumnSplit({
    required this.sourceColumn,
    required this.newColumns,
    this.byRegex = false,
    this.delimiter = '',
    this.pattern = '',
  });

  /// Compute the split values for a single source cell, aligned to
  /// [newColumns]. Each named column maps positionally to a split part;
  /// missing parts yield empty strings, extra parts are dropped. A blank
  /// name in [newColumns] skips that positional part (so the user can name
  /// only the parts they want, e.g. `,,period` to keep the 3rd whitespace
  /// token of `C/Azienda mese 01/2026`).
  List<String> splitCell(String cell) {
    final out = List<String>.filled(newColumns.length, '');
    if (byRegex) {
      final re = RowFilter._safeRegex(pattern);
      final m = re?.firstMatch(cell);
      if (m != null) {
        for (var i = 0; i < newColumns.length; i++) {
          final g = i + 1 <= m.groupCount ? m.group(i + 1) : null;
          out[i] = (g ?? '').trim();
        }
      }
      return out;
    }
    // Delimiter split. Empty/whitespace delimiter → split on whitespace runs.
    final useWhitespace = delimiter.trim().isEmpty;
    final parts = useWhitespace ? cell.trim().split(RegExp(r'\s+')) : cell.split(delimiter);
    for (var i = 0; i < newColumns.length; i++) {
      out[i] = i < parts.length ? parts[i].trim() : '';
    }
    return out;
  }

  /// Whether this split actually applies to [cell]. Used so multiple splits
  /// that write the SAME output columns (e.g. one keyed on delimiter "mese"
  /// for contribution rows, another on "AL" for the closing position row)
  /// can coexist: each only writes the rows it matches, leaving the others'
  /// results intact. A non-matching split is a no-op for that row.
  bool matches(String cell) {
    if (byRegex) {
      final re = RowFilter._safeRegex(pattern);
      return re != null && re.hasMatch(cell);
    }
    final useWhitespace = delimiter.trim().isEmpty;
    if (useWhitespace) {
      // Whitespace split "applies" when there are at least two tokens.
      return cell.trim().split(RegExp(r'\s+')).length >= 2;
    }
    // Delimiter split applies only when the delimiter is actually present.
    return cell.contains(delimiter);
  }

  Map<String, dynamic> toJson() => {
    'sourceColumn': sourceColumn,
    'newColumns': newColumns,
    'byRegex': byRegex,
    'delimiter': delimiter,
    'pattern': pattern,
  };

  static ColumnSplit fromJson(Map<String, dynamic> j) => ColumnSplit(
    sourceColumn: j['sourceColumn'] as String,
    newColumns: (j['newColumns'] as List<dynamic>).cast<String>(),
    byRegex: j['byRegex'] as bool? ?? false,
    delimiter: (j['delimiter'] as String?) ?? '',
    pattern: (j['pattern'] as String?) ?? '',
  );
}

/// The full set of post-parse preview transforms the wizard can apply,
/// in a fixed order: splits add columns first (so filters can target the
/// derived columns), then row filters drop/keep rows.
class PreviewTransforms {
  final List<ColumnSplit> splits;
  final List<RowFilter> filters;
  final FilterCombine combine;

  const PreviewTransforms({this.splits = const [], this.filters = const [], this.combine = FilterCombine.all});

  bool get isEmpty => splits.isEmpty && filters.isEmpty;

  /// Resulting column list after applying splits to [baseColumns]. New split
  /// columns are appended (deduped) in declaration order; the source column
  /// is kept so the user can still map or inspect it.
  List<String> transformColumns(List<String> baseColumns) {
    final cols = List<String>.of(baseColumns);
    for (final split in splits) {
      for (final nc in split.newColumns) {
        if (nc.isNotEmpty && !cols.contains(nc)) cols.add(nc);
      }
    }
    return cols;
  }

  /// Apply splits then filters to [rows], returning a new list. Pure; does
  /// not mutate the input rows.
  List<Map<String, String>> transformRows(List<Map<String, String>> rows) {
    Iterable<Map<String, String>> out = rows.map((r) => Map<String, String>.of(r));

    // 1. Splits: add derived columns. Multiple splits may target the SAME
    // output columns (different delimiters per row class); each writes only
    // the rows it matches, and every split reads the ORIGINAL source-column
    // value (captured before any split runs) so an earlier split rewriting
    // the source column doesn't change what a later split sees.
    if (splits.isNotEmpty) {
      final sourceCols = splits.map((s) => s.sourceColumn).toSet();
      out = out.map((row) {
        final original = {for (final c in sourceCols) c: row[c] ?? ''};
        for (final split in splits) {
          if (split.newColumns.isEmpty) continue;
          final cell = original[split.sourceColumn] ?? '';
          // Skip rows this split doesn't apply to, so a coexisting split's
          // result for those rows survives.
          if (!split.matches(cell)) continue;
          final parts = split.splitCell(cell);
          for (var i = 0; i < split.newColumns.length; i++) {
            final name = split.newColumns[i];
            if (name.isNotEmpty) row[name] = parts[i];
          }
        }
        return row;
      });
    }

    // 2. Filters: keep rows passing the combined predicate.
    if (filters.isNotEmpty) {
      out = out.where((row) {
        if (combine == FilterCombine.all) {
          return filters.every((f) => f.passes(row));
        }
        return filters.any((f) => f.passes(row));
      });
    }

    return out.toList();
  }
}
