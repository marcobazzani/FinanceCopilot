import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/services/import/preview_transforms.dart';

void main() {
  group('RowFilter', () {
    final row = {'Operazione': 'C/TFR mese 07/2021', 'Periodo': 'Totale Agosto 2021'};

    test('contains / notContains', () {
      expect(const RowFilter(column: 'Operazione', op: FilterOp.contains, value: 'C/').passes(row), isTrue);
      expect(const RowFilter(column: 'Periodo', op: FilterOp.notContains, value: 'Totale').passes(row), isFalse);
      expect(const RowFilter(column: 'Operazione', op: FilterOp.notContains, value: 'Totale').passes(row), isTrue);
    });

    test('equals / notEquals', () {
      expect(const RowFilter(column: 'Periodo', op: FilterOp.equals, value: 'Totale Agosto 2021').passes(row), isTrue);
      expect(const RowFilter(column: 'Periodo', op: FilterOp.notEquals, value: 'x').passes(row), isTrue);
    });

    test('matches / notMatches regex', () {
      expect(const RowFilter(column: 'Operazione', op: FilterOp.matches, value: r'\d{2}/\d{4}').passes(row), isTrue);
      expect(const RowFilter(column: 'Operazione', op: FilterOp.notMatches, value: r'XYZ').passes(row), isTrue);
    });

    test('invalid regex never throws; matches=false, notMatches=true', () {
      expect(const RowFilter(column: 'Operazione', op: FilterOp.matches, value: '([').passes(row), isFalse);
      expect(const RowFilter(column: 'Operazione', op: FilterOp.notMatches, value: '([').passes(row), isTrue);
    });

    test('missing column treated as empty string', () {
      expect(const RowFilter(column: 'Nope', op: FilterOp.contains, value: 'x').passes(row), isFalse);
      expect(const RowFilter(column: 'Nope', op: FilterOp.equals, value: '').passes(row), isTrue);
    });

    test('json round-trip', () {
      const f = RowFilter(column: 'A', op: FilterOp.notContains, value: 'foo');
      final back = RowFilter.fromJson(f.toJson());
      expect(back.column, 'A');
      expect(back.op, FilterOp.notContains);
      expect(back.value, 'foo');
    });
  });

  group('ColumnSplit', () {
    test('whitespace split into type/freq/period (the PPP case)', () {
      const split = ColumnSplit(sourceColumn: 'Operazione', newColumns: ['type', 'freq', 'period']);
      expect(split.splitCell('C/TFR mese 07/2021'), ['C/TFR', 'mese', '07/2021']);
      expect(split.splitCell('C/Azienda mese 01/2026'), ['C/Azienda', 'mese', '01/2026']);
    });

    test('positional mapping, extra parts dropped', () {
      const split = ColumnSplit(sourceColumn: 'x', newColumns: ['a', 'b']);
      expect(split.splitCell('one two three four'), ['one', 'two']);
    });

    test('splitCell returns all positional parts (skipping is applied at row level)', () {
      const split = ColumnSplit(sourceColumn: 'x', newColumns: ['', '', 'period']);
      expect(split.splitCell('C/Azienda mese 01/2026'), ['C/Azienda', 'mese', '01/2026']);
    });

    test('delimiter split keeps only named positions', () {
      const split = ColumnSplit(sourceColumn: 'x', newColumns: ['before', 'after'], delimiter: 'mese');
      expect(split.splitCell('C/Azienda mese 01/2026'), ['C/Azienda', '01/2026']);
    });

    test('missing parts yield empty strings', () {
      const split = ColumnSplit(sourceColumn: 'x', newColumns: ['a', 'b', 'c']);
      expect(split.splitCell('only'), ['only', '', '']);
    });

    test('explicit delimiter', () {
      const split = ColumnSplit(sourceColumn: 'x', newColumns: ['a', 'b'], delimiter: ',');
      expect(split.splitCell('foo,bar'), ['foo', 'bar']);
    });

    test('regex capture groups', () {
      const split = ColumnSplit(
        sourceColumn: 'x',
        newColumns: ['type', 'period'],
        byRegex: true,
        pattern: r'(C/\w+).*?(\d{2}/\d{4})',
      );
      expect(split.splitCell('C/TFR mese 07/2021'), ['C/TFR', '07/2021']);
    });

    test('regex no match yields empty cells', () {
      const split = ColumnSplit(sourceColumn: 'x', newColumns: ['a'], byRegex: true, pattern: r'(\d+)');
      expect(split.splitCell('no digits'), ['']);
    });

    test('json round-trip', () {
      const split = ColumnSplit(sourceColumn: 'Op', newColumns: ['t', 'p'], byRegex: true, pattern: 'x');
      final back = ColumnSplit.fromJson(split.toJson());
      expect(back.sourceColumn, 'Op');
      expect(back.newColumns, ['t', 'p']);
      expect(back.byRegex, isTrue);
      expect(back.pattern, 'x');
    });

    test('matches() — delimiter present / absent', () {
      const s = ColumnSplit(sourceColumn: 'x', newColumns: ['a', 'b'], delimiter: 'mese');
      expect(s.matches('C/Azienda mese 01/2026'), isTrue);
      expect(s.matches('POSIZIONE INDIVIDUALE AL 05/2026'), isFalse);
    });

    test('matches() — whitespace needs 2+ tokens; regex uses hasMatch', () {
      const ws = ColumnSplit(sourceColumn: 'x', newColumns: ['a', 'b']);
      expect(ws.matches('one two'), isTrue);
      expect(ws.matches('single'), isFalse);
      const re = ColumnSplit(sourceColumn: 'x', newColumns: ['a'], byRegex: true, pattern: r'\d{2}/\d{4}');
      expect(re.matches('01/2026'), isTrue);
      expect(re.matches('no date'), isFalse);
    });
  });

  group('PreviewTransforms', () {
    final rows = [
      {'Periodo': 'Agosto 2021', 'Operazione': 'C/TFR mese 07/2021', 'Entrate': '402,95'},
      {'Periodo': 'Totale Agosto 2021', 'Operazione': '', 'Entrate': '402,95'},
      {'Periodo': 'Gennaio 2026', 'Operazione': 'C/Azienda mese 01/2026', 'Entrate': '358,35'},
    ];

    test('split then filter — mimics form3.sh (keep C/, drop Totale)', () {
      const t = PreviewTransforms(
        splits: [
          ColumnSplit(sourceColumn: 'Operazione', newColumns: ['type', 'freq', 'period']),
        ],
        filters: [
          RowFilter(column: 'Operazione', op: FilterOp.contains, value: 'C/'),
          RowFilter(column: 'Periodo', op: FilterOp.notContains, value: 'Totale'),
        ],
      );
      final out = t.transformRows(rows);
      expect(out.length, 2);
      expect(out[0]['type'], 'C/TFR');
      expect(out[0]['period'], '07/2021');
      expect(out[1]['type'], 'C/Azienda');
      expect(out.every((r) => !r['Periodo']!.contains('Totale')), isTrue);
    });

    test('combine=any keeps rows passing at least one filter', () {
      const t = PreviewTransforms(
        filters: [
          RowFilter(column: 'Periodo', op: FilterOp.contains, value: 'Totale'),
          RowFilter(column: 'Operazione', op: FilterOp.contains, value: 'C/Azienda'),
        ],
        combine: FilterCombine.any,
      );
      final out = t.transformRows(rows);
      expect(out.length, 2);
    });

    test('blank-named split parts are not written as columns on rows', () {
      const t = PreviewTransforms(
        splits: [
          ColumnSplit(sourceColumn: 'Operazione', newColumns: ['', '', 'period']),
        ],
      );
      final out = t.transformRows(rows);
      expect(out[0]['period'], '07/2021');
      expect(out[0].containsKey(''), isFalse);
    });

    test('transformColumns appends new split columns, keeps source', () {
      const t = PreviewTransforms(
        splits: [
          ColumnSplit(sourceColumn: 'Operazione', newColumns: ['type', 'period']),
        ],
      );
      final cols = t.transformColumns(['Periodo', 'Operazione', 'Entrate']);
      expect(cols, ['Periodo', 'Operazione', 'Entrate', 'type', 'period']);
    });

    test('does not mutate input rows', () {
      const t = PreviewTransforms(
        splits: [
          ColumnSplit(sourceColumn: 'Operazione', newColumns: ['type']),
        ],
      );
      t.transformRows(rows);
      expect(rows[0].containsKey('type'), isFalse);
    });

    test('empty transforms are a no-op passthrough', () {
      const t = PreviewTransforms();
      expect(t.isEmpty, isTrue);
      final out = t.transformRows(rows);
      expect(out.length, rows.length);
    });

    test('two splits writing the SAME output columns coexist — each only '
        'rewrites the rows it matches (PPP: "mese" vs "AL")', () {
      // Both splits target Operazione → [Operazione, Data] but with different
      // delimiters: "mese" for monthly contributions, "AL" for the closing
      // position row. A non-matching split must NOT clobber the other's
      // result.
      final ppp = [
        {'Operazione': 'C/Azienda mese 01/2026', 'Saldo': ''},
        {'Operazione': 'POSIZIONE INDIVIDUALE AL 05/2026', 'Saldo': '52.610,23'},
        {'Operazione': 'POSIZIONE INDIVIDUALE 01/01', 'Saldo': '47.984,24'},
      ];
      const t = PreviewTransforms(
        splits: [
          ColumnSplit(sourceColumn: 'Operazione', newColumns: ['Operazione', 'Data'], delimiter: 'mese'),
          ColumnSplit(sourceColumn: 'Operazione', newColumns: ['Operazione', 'Data'], delimiter: ' AL '),
        ],
      );
      final out = t.transformRows(ppp);

      // Contribution row: split on "mese" wins; " AL " split is a no-op here.
      expect(out[0]['Operazione'], 'C/Azienda');
      expect(out[0]['Data'], '01/2026');

      // Closing position row: split on " AL " wins; "mese" split is a no-op.
      // Note " AL " is spaced to avoid matching inside "INDIVIDUALE".
      expect(out[1]['Operazione'], 'POSIZIONE INDIVIDUALE');
      expect(out[1]['Data'], '05/2026');

      // Opening position row matches neither delimiter: source untouched,
      // Data never written.
      expect(out[2]['Operazione'], 'POSIZIONE INDIVIDUALE 01/01');
      expect(out[2].containsKey('Data'), isFalse);
    });

    test('a non-matching delimiter split leaves the row untouched', () {
      const t = PreviewTransforms(
        splits: [
          ColumnSplit(sourceColumn: 'Operazione', newColumns: ['a', 'b'], delimiter: 'ZZZ'),
        ],
      );
      final out = t.transformRows([
        {'Operazione': 'C/Azienda mese 01/2026'},
      ]);
      expect(out[0].containsKey('a'), isFalse, reason: 'no ZZZ in cell → split is a no-op');
      expect(out[0]['Operazione'], 'C/Azienda mese 01/2026');
    });
  });
}
