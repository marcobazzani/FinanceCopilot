import 'package:finance_copilot/utils/amount_parser.dart' as amt;
import 'package:finance_copilot/utils/date_parser.dart' as dateparse;
import 'package:finance_copilot/services/pdf_exceptions.dart';

part 'pdf_table_models.dart';

/// One positioned text run extracted from a PDF page. PDF page coordinates
/// have origin at bottom-left, so [top] > [bottom]. Pages are 1-indexed.
class PdfFragment {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int page;

  const PdfFragment({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.page,
  });

  double get xCenter => (left + right) / 2;
  double get yCenter => (top + bottom) / 2;
  double get height => (top - bottom).abs();
  double get width => (right - left).abs();
}

/// Output of the reconstructor: column headers + 2D row cells.
class PdfTableReconstruction {
  final List<String> columns;
  final List<List<String>> rows;
  const PdfTableReconstruction({required this.columns, required this.rows});
}

/// Anchor-based PDF table reconstructor. Pure Dart, no Flutter or pdfrx
/// dependency, so it runs in unit tests against synthetic fragments.
///
/// See the design document at `.claude/plans/soft-nibbling-wozniak.md` for
/// the full algorithm. The short version: domain anchors (date column +
/// amount column) come first, then middle columns are filled in by
/// gap-stable left-edge clustering, then the result is validated row-by-row
/// before emission. Any failure throws a [PdfImportException] subclass —
/// per CLAUDE.md "never silently fall back".
class PdfTableReconstructor {
  /// Locales the rest of the import wizard supports. Used as the candidate
  /// set when probing whether a fragment is "numeric" — a fragment counts
  /// if `tryParseAmount` succeeds under at least one of these.
  static const candidateLocales = [
    'en_US',
    'it_IT',
    'de_DE',
    'fr_FR',
    'es_ES',
    'en_GB',
  ];

  /// Minimum fraction of candidate-data lines whose date fragment must land
  /// in the dominant date cluster.
  static const _dateAnchorSupport = 0.40;

  /// Minimum fraction of data lines whose numeric fragment must land in
  /// the dominant amount cluster.
  static const _amountAnchorSupport = 0.60;

  /// A second amount cluster is promoted to a balance column when its
  /// support is at least this fraction of the primary amount cluster's.
  static const _balanceSupportRatio = 0.80;

  /// Minimum support for a middle-column anchor (fraction of data lines
  /// whose left-edge falls in the cluster).
  static const _middleColSupport = 0.70;

  /// Validation: at least this fraction of emitted rows must have a
  /// parseable date in the date column AND a parseable amount in the
  /// amount column.
  static const _rowValidationSupport = 0.80;

  /// Reject very-short inputs as not-a-text-layer up front. Below this we
  /// throw [PdfNoTextLayerException]; above this but failing further checks
  /// we throw [PdfTableNotDetectedException].
  static const _minFragmentsForTextLayer = 10;

  /// Reject fragments where >30% of characters are in the Unicode
  /// Private-Use-Area, which signals a broken `ToUnicode` CMap.
  static const _puaThreshold = 0.30;

  static PdfTableReconstruction reconstruct(List<PdfFragment> fragments) {
    if (fragments.length < _minFragmentsForTextLayer) {
      throw const PdfNoTextLayerException(
        'PDF text layer is empty or too sparse to extract a table.',
      );
    }
    _checkPua(fragments);

    final cleaned = _dropPageChrome(fragments);
    if (cleaned.length < _minFragmentsForTextLayer) {
      throw const PdfTableNotDetectedException(
        'Almost everything was page chrome; no body text remained.',
      );
    }

    final lines = _clusterLines(cleaned);
    if (lines.length < 5) {
      throw const PdfTableNotDetectedException(
        'Fewer than 5 text lines after Y-clustering.',
      );
    }

    final charWidth = _medianCharWidth(cleaned);
    final lineHeight = _medianLineHeight(cleaned);

    final dateAnchor = _anchorDateColumn(lines, charWidth);
    final dataLineIndices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_lineHasDateInBand(lines[i], dateAnchor)) dataLineIndices.add(i);
    }
    if (dataLineIndices.length < 5) {
      throw const PdfTableNotDetectedException(
        'Fewer than 5 lines anchored on the dominant date column.',
      );
    }

    final amountAnchor = _anchorAmountColumn(lines, dataLineIndices, charWidth);
    final balanceAnchor = _anchorBalanceColumn(
      lines,
      dataLineIndices,
      dateAnchor,
      amountAnchor,
      charWidth,
    );

    final middleAnchors = _detectMiddleColumns(
      lines,
      dataLineIndices,
      dateAnchor: dateAnchor,
      amountAnchor: amountAnchor,
      balanceAnchor: balanceAnchor,
      charWidth: charWidth,
    );

    final dataAnchors = <_ColAnchor>[
      dateAnchor,
      ...middleAnchors,
      amountAnchor,
      ?balanceAnchor,
    ]..sort((a, b) => a.xLeft.compareTo(b.xLeft));

    // Header detection runs BEFORE the final cell assignment so a clean
    // text-only header row above the data can introduce synthetic anchors
    // for columns the data alone wouldn't reveal — e.g. an "Uscite"
    // (debits) column whose value is empty for every row in this report
    // but whose header is clearly printed above. Without this step those
    // headers would either (a) merge with their nearest data anchor and
    // produce labels like "Entrate Uscite", or (b) be dropped entirely.
    final headerLineIndex = _findHeaderLine(lines, dataLineIndices.first);
    final allAnchors = headerLineIndex != null ? _augmentAnchorsWithHeader(dataAnchors, lines[headerLineIndex], charWidth) : dataAnchors;

    final boundaries = _columnBoundaries(allAnchors);

    final lineCells = lines.map((line) => _assignCells(line, boundaries)).toList();

    final dateColIdx = allAnchors.indexWhere((a) => identical(a, dateAnchor));
    final amountColIdx = allAnchors.indexWhere((a) => identical(a, amountAnchor));

    final columns = headerLineIndex != null
        ? List<String>.generate(
            allAnchors.length,
            (k) => k < lineCells[headerLineIndex].length && lineCells[headerLineIndex][k].isNotEmpty
                ? lineCells[headerLineIndex][k]
                : 'Column ${k + 1}',
          )
        : List<String>.generate(allAnchors.length, (i) => 'Column ${i + 1}');

    if (columns.length < 2 || columns.length > 12) {
      throw const PdfTableNotDetectedException(
        'Detected column count is outside the sane 2..12 range.',
      );
    }

    final dataLineSet = dataLineIndices.toSet();
    final mergedRows = _mergeWraps(
      lines: lines,
      lineCells: lineCells,
      dataLineSet: dataLineSet,
      dateAnchor: dateAnchor,
      amountAnchor: amountAnchor,
      balanceAnchor: balanceAnchor,
      lineHeight: lineHeight,
    );

    if (mergedRows.isEmpty) {
      throw const PdfTableNotDetectedException(
        'Reconstruction produced zero data rows.',
      );
    }

    final dateOk = mergedRows.where((r) => _cellHasDate(_safeCell(r, dateColIdx))).length;
    final amtOk = mergedRows.where((r) => _tryAnyLocaleAmount(_safeCell(r, amountColIdx)) != null).length;
    final dateRatio = dateOk / mergedRows.length;
    final amtRatio = amtOk / mergedRows.length;
    if (dateRatio < _rowValidationSupport || amtRatio < _rowValidationSupport) {
      throw const PdfTableNotDetectedException(
        'Per-row validation failed: too many rows lack a parseable date or amount.',
      );
    }

    return PdfTableReconstruction(columns: columns, rows: mergedRows);
  }

  // ────────────────────────────────────────────────────────
  // Step 0: PUA / glyph-id sanity check
  // ────────────────────────────────────────────────────────

  static void _checkPua(List<PdfFragment> fragments) {
    var totalChars = 0;
    var puaChars = 0;
    for (final f in fragments) {
      for (final code in f.text.runes) {
        totalChars++;
        if ((code >= 0xE000 && code <= 0xF8FF) || (code >= 0xF0000 && code <= 0xFFFFD) || (code >= 0x100000 && code <= 0x10FFFD)) {
          puaChars++;
        }
      }
    }
    if (totalChars > 0 && puaChars / totalChars > _puaThreshold) {
      throw const PdfUnreadableTextException(
        'PDF text layer contains too many glyph-id characters; '
        'the producer omitted a usable ToUnicode CMap.',
      );
    }
  }

  // ────────────────────────────────────────────────────────
  // Step 1: drop repeating page chrome
  // ────────────────────────────────────────────────────────

  static List<PdfFragment> _dropPageChrome(List<PdfFragment> fragments) {
    final byKey = <String, Set<int>>{};
    for (final f in fragments) {
      final t = f.text.trim();
      if (t.isEmpty) continue;
      final key = '$t|${(f.top / 2).round()}';
      byKey.putIfAbsent(key, () => <int>{}).add(f.page);
    }
    final chromeKeys = <String>{};
    for (final entry in byKey.entries) {
      if (entry.value.length >= 3) chromeKeys.add(entry.key);
    }
    return fragments.where((f) {
      final t = f.text.trim();
      if (t.isEmpty) return false;
      final key = '$t|${(f.top / 2).round()}';
      return !chromeKeys.contains(key);
    }).toList();
  }

  // ────────────────────────────────────────────────────────
  // Step 2: line clustering (Y, per page)
  // ────────────────────────────────────────────────────────

  static List<_Line> _clusterLines(List<PdfFragment> fragments) {
    final byPage = <int, List<PdfFragment>>{};
    for (final f in fragments) {
      byPage.putIfAbsent(f.page, () => <PdfFragment>[]).add(f);
    }
    final pages = byPage.keys.toList()..sort();
    final lines = <_Line>[];
    final h = _medianLineHeight(fragments);
    final tolerance = h * 0.6;

    for (final p in pages) {
      final pageFrags = byPage[p]!..sort((a, b) => b.yCenter.compareTo(a.yCenter)); // top → down
      List<PdfFragment> bucket = [];
      double? bucketY;
      for (final f in pageFrags) {
        if (bucket.isEmpty || bucketY == null) {
          bucket = [f];
          bucketY = f.yCenter;
          continue;
        }
        if ((bucketY - f.yCenter).abs() <= tolerance) {
          bucket.add(f);
          // running median (cheap update: re-sort when small)
          final ys = bucket.map((e) => e.yCenter).toList()..sort();
          bucketY = ys[ys.length ~/ 2];
        } else {
          lines.add(_finalizeLine(p, bucket));
          bucket = [f];
          bucketY = f.yCenter;
        }
      }
      if (bucket.isNotEmpty) lines.add(_finalizeLine(p, bucket));
    }
    return lines;
  }

  static _Line _finalizeLine(int page, List<PdfFragment> frags) {
    frags.sort((a, b) => a.left.compareTo(b.left));
    final ys = frags.map((e) => e.yCenter).toList()..sort();
    return _Line(page: page, fragments: frags, medianY: ys[ys.length ~/ 2]);
  }

  // ────────────────────────────────────────────────────────
  // Step 3: anchor the date column
  // ────────────────────────────────────────────────────────

  static _ColAnchor _anchorDateColumn(List<_Line> lines, double charWidth) {
    // Per-line date positions, including dates whose text was split by
    // pdfrx into adjacent fragments (e.g. "Gennaio" + "2026", or "Jan" +
    // "15," + "2024"). Without stitching we'd miss these entirely.
    final perLine = <int, List<_DatePos>>{};
    var candidateLines = 0;
    for (var i = 0; i < lines.length; i++) {
      final positions = _findDatesInLine(lines[i]);
      if (positions.isEmpty) continue;
      perLine[i] = positions;
      candidateLines++;
    }
    if (candidateLines == 0) {
      throw const PdfTableNotDetectedException(
        'No lines contain a parseable date — not a transaction table.',
      );
    }

    final allCenters = <double>[];
    for (final list in perLine.values) {
      for (final p in list) {
        allCenters.add(p.xCenter);
      }
    }
    final clusters = _cluster1D(
      allCenters,
      mergeThreshold: charWidth * 3,
    );
    if (clusters.isEmpty) {
      throw const PdfTableNotDetectedException(
        'Date X-positions did not cluster.',
      );
    }

    // Score each cluster by how many DISTINCT lines contain a date in it.
    // Counting lines (not fragments) is what we actually care about: a
    // line with 5 dates in one cluster shouldn't outweigh 5 lines with
    // one date each. Tiebreak by leftmost — the date column convention.
    _Cluster1D? best;
    var bestLines = 0;
    for (final c in clusters) {
      var supporting = 0;
      for (final entry in perLine.entries) {
        for (final p in entry.value) {
          if (p.xCenter >= c.lo && p.xCenter <= c.hi) {
            supporting++;
            break;
          }
        }
      }
      if (best == null || supporting > bestLines || (supporting == bestLines && c.center < best.center)) {
        best = c;
        bestLines = supporting;
      }
    }

    if (best == null || bestLines / candidateLines < _dateAnchorSupport) {
      throw const PdfTableNotDetectedException(
        'Dominant date cluster has weak support across candidate lines.',
      );
    }

    // Track the actual left/right edges of dates anchored to this column.
    // We START with positions whose xCenter sits inside the dominant
    // cluster, then iteratively pull in any other date position whose
    // xCenter already falls inside the current band — this expands xHi
    // to cover stitched dates that extend past the cluster (e.g. a
    // subtotal row's "Gennaio 2026" stitch sits a few points right of
    // the per-row stitch because of the leading "Totale" word, but the
    // date is still semantically in the same column).
    final lefts = <double>[];
    final rights = <double>[];
    var bandLo = best.lo - charWidth;
    var bandHi = best.hi + charWidth;
    bool changed = true;
    while (changed) {
      changed = false;
      for (final list in perLine.values) {
        for (final p in list) {
          if (p.xCenter < bandLo || p.xCenter > bandHi) continue;
          if (p.right + charWidth > bandHi) {
            bandHi = p.right + charWidth;
            changed = true;
          }
          if (p.left - charWidth < bandLo) {
            bandLo = p.left - charWidth;
            changed = true;
          }
        }
      }
    }
    for (final list in perLine.values) {
      for (final p in list) {
        if (p.xCenter >= bandLo && p.xCenter <= bandHi) {
          lefts.add(p.left);
          rights.add(p.right);
        }
      }
    }
    return _ColAnchor(
      role: _ColRole.date,
      xLeft: _median(lefts),
      xLo: bandLo,
      xHi: bandHi,
    );
  }

  /// Find every parseable-date position in [line], including ones whose
  /// text was split across adjacent fragments. Greedy non-overlapping:
  /// at each fragment we try the longest stitch (up to 3 fragments) that
  /// parses, then advance past it.
  ///
  /// Capping at 3 covers practical formats: "Jan 15, 2024" (3),
  /// "Gennaio 2026" (2), "01/2024" (1). Going wider would invite false
  /// positives where a date-shaped substring sits inside a longer phrase.
  static List<_DatePos> _findDatesInLine(_Line line) {
    final frags = line.fragments;
    final out = <_DatePos>[];
    var i = 0;
    while (i < frags.length) {
      int? bestEnd;
      final maxJ = (i + 3 <= frags.length) ? i + 3 : frags.length;
      for (var j = i; j < maxJ; j++) {
        final combined = frags.sublist(i, j + 1).map((f) => f.text.trim()).where((t) => t.isNotEmpty).join(' ');
        if (_looksLikeDate(combined)) {
          bestEnd = j;
        }
      }
      if (bestEnd != null) {
        final left = frags[i].left;
        final right = frags[bestEnd].right;
        out.add(_DatePos(left: left, right: right));
        i = bestEnd + 1;
      } else {
        i++;
      }
    }
    return out;
  }

  // ────────────────────────────────────────────────────────
  // Step 4: anchor amount + optional balance
  // ────────────────────────────────────────────────────────

  static _ColAnchor _anchorAmountColumn(
    List<_Line> lines,
    List<int> dataLineIndices,
    double charWidth,
  ) {
    final numerics = <_FragmentInLine>[];
    final supportByLine = <int, List<_FragmentInLine>>{};
    for (final i in dataLineIndices) {
      final ns = lines[i].fragments.where((f) => _tryAnyLocaleAmount(f.text) != null).toList();
      for (final f in ns) {
        final fil = _FragmentInLine(lineIndex: i, fragment: f);
        numerics.add(fil);
        supportByLine.putIfAbsent(i, () => <_FragmentInLine>[]).add(fil);
      }
    }
    if (numerics.isEmpty) {
      throw const PdfTableNotDetectedException(
        'No numeric fragments on data lines — no amount column to anchor.',
      );
    }
    final clusters = _cluster1D(
      numerics.map((n) => n.fragment.xCenter).toList(),
      mergeThreshold: charWidth * 3,
    );
    if (clusters.isEmpty) {
      throw const PdfTableNotDetectedException(
        'Amount X-positions did not cluster.',
      );
    }
    // Walk clusters right-to-left and pick the first one that meets the
    // support threshold. A right-most cluster that only fires on a few
    // rows (e.g. a Saldo column with values only on subtotal rows) would
    // fail support; the real per-row amount column sits to its left and
    // covers every data line.
    clusters.sort((a, b) => b.center.compareTo(a.center));
    _Cluster1D? chosen;
    Set<int>? chosenSupport;
    for (final c in clusters) {
      final supportLines = numerics
          .where((n) => n.fragment.xCenter >= c.lo - charWidth && n.fragment.xCenter <= c.hi + charWidth)
          .map((n) => n.lineIndex)
          .toSet();
      if (supportLines.length / dataLineIndices.length >= _amountAnchorSupport) {
        chosen = c;
        chosenSupport = supportLines;
        break;
      }
    }
    if (chosen == null || chosenSupport == null) {
      throw const PdfTableNotDetectedException(
        'No numeric cluster has sufficient support across data lines.',
      );
    }

    final lefts = numerics
        .where(
          (n) =>
              chosenSupport!.contains(n.lineIndex) &&
              n.fragment.xCenter >= chosen!.lo - charWidth &&
              n.fragment.xCenter <= chosen.hi + charWidth,
        )
        .map((n) => n.fragment.left)
        .toList();
    return _ColAnchor(
      role: _ColRole.amount,
      xLeft: _median(lefts),
      xLo: chosen.lo - charWidth,
      xHi: chosen.hi + charWidth,
    );
  }

  static _ColAnchor? _anchorBalanceColumn(
    List<_Line> lines,
    List<int> dataLineIndices,
    _ColAnchor date,
    _ColAnchor amount,
    double charWidth,
  ) {
    // Numeric clusters NOT overlapping with the amount column. Searched on
    // BOTH sides — most layouts put balance to the right of amount, but a
    // few (and the existing "amount = right-most" tests) put it to the
    // left. We don't care which side; we just want the second numeric
    // column with a credible amount of signal. Also exclude fragments
    // inside the date band — a bare year like "2026" inside the date
    // column parses as a number and would otherwise hijack a balance
    // anchor between the month and the year.
    final candidates = <_FragmentInLine>[];
    for (final i in dataLineIndices) {
      final frags = lines[i].fragments.where(
        (f) => _tryAnyLocaleAmount(f.text) != null && !_xInBand(f.xCenter, amount) && !_xInBand(f.xCenter, date),
      );
      for (final f in frags) {
        candidates.add(_FragmentInLine(lineIndex: i, fragment: f));
      }
    }
    if (candidates.isEmpty) return null;
    final clusters = _cluster1D(
      candidates.map((c) => c.fragment.xCenter).toList(),
      mergeThreshold: charWidth * 3,
    );
    if (clusters.isEmpty) return null;
    // Prefer right-most. Existing tests expect [date, desc, amount-col,
    // balance-col] grids to anchor "balance" on the second-rightmost
    // numeric (i.e. the geometric amount column), with header detection
    // labelling cells correctly.
    clusters.sort((a, b) => b.center.compareTo(a.center));
    final secondMost = clusters.first;

    final supportLines = candidates
        .where((c) => c.fragment.xCenter >= secondMost.lo - charWidth && c.fragment.xCenter <= secondMost.hi + charWidth)
        .map((c) => c.lineIndex)
        .toSet();

    // Two acceptance paths:
    //  - "Dense" balance column (the typical second-numeric-column case):
    //    must reach _balanceSupportRatio of amount support.
    //  - "Sparse" balance column (PPP-style: Saldo only on subtotal rows):
    //    accept any cluster with at least 2 supporting lines, provided
    //    it sits clearly RIGHT of the amount column. This recovers the
    //    Saldo cells on subtotal rows without forcing them to be jammed
    //    into the amount cell.
    final amountSupport = (dataLineIndices.length * _amountAnchorSupport).ceil();
    final isDense = supportLines.length >= amountSupport * _balanceSupportRatio;
    final isSparseRight = !isDense && supportLines.length >= 2 && secondMost.lo > amount.xHi;
    if (!isDense && !isSparseRight) {
      return null;
    }

    // The plan calls this the *balance* column and places it semantically
    // before the amount column. We anchor it on `_ColRole.balance` so the
    // header detector can label it generically; the wizard's auto-mapper
    // and the user's column picker take care of routing.
    final lefts = candidates
        .where(
          (c) =>
              supportLines.contains(c.lineIndex) &&
              c.fragment.xCenter >= secondMost.lo - charWidth &&
              c.fragment.xCenter <= secondMost.hi + charWidth,
        )
        .map((c) => c.fragment.left)
        .toList();
    return _ColAnchor(
      role: _ColRole.balance,
      xLeft: _median(lefts),
      xLo: secondMost.lo - charWidth,
      xHi: secondMost.hi + charWidth,
    );
  }

  // ────────────────────────────────────────────────────────
  // Step 5: middle columns from gap-stable left-edge clustering
  // ────────────────────────────────────────────────────────

  static List<_ColAnchor> _detectMiddleColumns(
    List<_Line> lines,
    List<int> dataLineIndices, {
    required _ColAnchor dateAnchor,
    required _ColAnchor amountAnchor,
    required _ColAnchor? balanceAnchor,
    required double charWidth,
  }) {
    // Middle columns sit strictly BETWEEN date and amount. Balance can be
    // on either side of amount, so we exclude its band explicitly — but
    // we don't use it as a boundary, because the amount column itself
    // would otherwise become a middle-column candidate.
    final lefts = <_FragmentInLine>[];
    final perLineCounts = <int, Set<int>>{};
    for (final i in dataLineIndices) {
      perLineCounts[i] = <int>{};
      for (final f in lines[i].fragments) {
        if (f.xCenter <= dateAnchor.xHi) continue;
        if (f.xCenter >= amountAnchor.xLo) continue;
        if (balanceAnchor != null && _xInBand(f.xCenter, balanceAnchor)) {
          continue;
        }
        lefts.add(_FragmentInLine(lineIndex: i, fragment: f));
      }
    }
    if (lefts.isEmpty) return const [];

    final clusters = _cluster1D(
      lefts.map((l) => l.fragment.left).toList(),
      mergeThreshold: charWidth * 2,
    );

    // Compute support: for each cluster, count distinct data lines that
    // contributed at least one fragment.
    final accepted = <_ColAnchor>[];
    for (final c in clusters) {
      final supportingLines = <int>{};
      for (final f in lefts) {
        if (f.fragment.left >= c.lo - charWidth * 0.5 && f.fragment.left <= c.hi + charWidth * 0.5) {
          supportingLines.add(f.lineIndex);
        }
      }
      if (supportingLines.length / dataLineIndices.length < _middleColSupport) {
        continue;
      }
      final memberLefts = lefts
          .where((f) => f.fragment.left >= c.lo - charWidth * 0.5 && f.fragment.left <= c.hi + charWidth * 0.5)
          .map((f) => f.fragment.left)
          .toList();
      accepted.add(
        _ColAnchor(
          role: _ColRole.middle,
          xLeft: _median(memberLefts),
          xLo: c.lo,
          xHi: c.hi,
        ),
      );
    }
    if (accepted.isNotEmpty) {
      accepted.sort((a, b) => a.xLeft.compareTo(b.xLeft));
      return accepted;
    }

    // Fallback: when no per-column structure passes the support threshold
    // — typically because some data lines are summary rows that don't have
    // every column populated — anchor a single "description" column that
    // spans the whole gap between date and amount (excluding any balance
    // band that sits in there). This lets the cell-assigner sweep the
    // free-floating description fragments out of the date column.
    final linesWithMiddle = lefts.map((f) => f.lineIndex).toSet();
    if (linesWithMiddle.length / dataLineIndices.length < 0.50) {
      return const [];
    }
    final fallbackLefts = lefts.map((f) => f.fragment.left).toList();
    final fallbackRights = lefts.map((f) => f.fragment.right).toList();
    final spanLeft = fallbackLefts.reduce((a, b) => a < b ? a : b) - charWidth * 0.5;
    final spanRight = fallbackRights.reduce((a, b) => a > b ? a : b) + charWidth * 0.5;
    return [
      _ColAnchor(
        role: _ColRole.middle,
        xLeft: _median(fallbackLefts),
        xLo: spanLeft,
        xHi: spanRight,
      ),
    ];
  }

  // ────────────────────────────────────────────────────────
  // Step 6: cell assignment
  // ────────────────────────────────────────────────────────

  static List<double> _columnBoundaries(List<_ColAnchor> anchors) {
    // Boundary i is the START of column i. Column i spans
    // [boundaries[i], boundaries[i+1]) — last column extends to +inf.
    //
    // boundary[0] is anchor[0].xLo so fragments to the left of the first
    // column still get bucketed into it. Subsequent boundaries are the
    // MIDPOINTS between consecutive anchor xLeft positions. Midpoints
    // matter because column header text is typically center-aligned over
    // its column while numeric data is right-aligned; an xLo-only scheme
    // makes a center-aligned "Saldo" header land in its left neighbour.
    if (anchors.isEmpty) return const [];
    final out = <double>[anchors.first.xLo];
    for (var i = 1; i < anchors.length; i++) {
      out.add((anchors[i - 1].xLeft + anchors[i].xLeft) / 2);
    }
    return out;
  }

  static List<String> _assignCells(_Line line, List<double> boundaries) {
    final n = boundaries.length;
    final buckets = List.generate(n, (_) => <PdfFragment>[]);
    for (final f in line.fragments) {
      // Right-aligned numeric cells often have a `left` that lands before
      // the column boundary even when the content geometrically belongs to
      // that column. Use the fragment's x-center for assignment instead.
      final assignX = f.xCenter;
      var idx = 0;
      for (var b = 1; b < n; b++) {
        if (assignX >= boundaries[b]) {
          idx = b;
        } else {
          break;
        }
      }
      buckets[idx].add(f);
    }
    return buckets
        .map((b) => (b..sort((a, c) => a.left.compareTo(c.left))).map((f) => f.text.trim()).where((t) => t.isNotEmpty).join(' '))
        .toList();
  }

  // ────────────────────────────────────────────────────────
  // Step 7: merge wrapped continuation lines into data rows
  // ────────────────────────────────────────────────────────

  static List<List<String>> _mergeWraps({
    required List<_Line> lines,
    required List<List<String>> lineCells,
    required Set<int> dataLineSet,
    required _ColAnchor dateAnchor,
    required _ColAnchor amountAnchor,
    required _ColAnchor? balanceAnchor,
    required double lineHeight,
  }) {
    final rows = <List<String>>[];
    var i = 0;
    while (i < lines.length) {
      if (!dataLineSet.contains(i)) {
        i++;
        continue;
      }
      final cells = List<String>.from(lineCells[i]);
      var j = i + 1;
      while (j < lines.length && !dataLineSet.contains(j) && lines[j].page == lines[i].page) {
        // A continuation line never carries a numeric in an anchored
        // money column. The check covers both amount AND balance — a
        // closing-position row ("POSIZIONE INDIVIDUALE AL 04/2026
        // 51.413,52") sits below the last subtotal with its value in
        // the balance band only, so without including balance the wrap
        // would absorb it into the previous row.
        final hasAnchoredAmount = lines[j].fragments.any((f) {
          if (_tryAnyLocaleAmount(f.text) == null) return false;
          if (_xInBand(f.xCenter, amountAnchor)) return true;
          if (balanceAnchor != null && _xInBand(f.xCenter, balanceAnchor)) {
            return true;
          }
          return false;
        });
        if (hasAnchoredAmount) break;
        final gap = lines[j - 1].medianY - lines[j].medianY;
        if (gap < 0 || gap > lineHeight * 1.6) break;
        // Continuation: append non-empty cells.
        var anyMerged = false;
        for (var c = 0; c < cells.length; c++) {
          final extra = (c < lineCells[j].length) ? lineCells[j][c] : '';
          if (extra.isNotEmpty) {
            cells[c] = cells[c].isEmpty ? extra : '${cells[c]} $extra';
            anyMerged = true;
          }
        }
        if (!anyMerged) break;
        j++;
      }
      rows.add(cells);
      i = j;
    }
    return rows;
  }

  // ────────────────────────────────────────────────────────
  // Header detection
  // ────────────────────────────────────────────────────────

  /// Find the line index of the table header above the first data line,
  /// or null if no clean header row exists. A header line has 2+ text
  /// fragments and contains no parseable date or amount (those would
  /// indicate a data row, not a header). Walks UP from the first data
  /// line; the first qualifying line wins.
  static int? _findHeaderLine(List<_Line> lines, int firstDataLineIndex) {
    for (var i = firstDataLineIndex - 1; i >= 0; i--) {
      if (lines[i].page != lines[firstDataLineIndex].page) continue;
      final nonEmpty = lines[i].fragments.where((f) => f.text.trim().isNotEmpty).toList();
      if (nonEmpty.length < 2) continue;
      if (nonEmpty.any((f) => _looksLikeDate(f.text))) continue;
      if (nonEmpty.any((f) => _tryAnyLocaleAmount(f.text) != null)) continue;
      return i;
    }
    return null;
  }

  /// Augment a data-driven anchor list with synthetic anchors for header
  /// words that don't have a data column underneath them.
  ///
  /// Each header word is snapped to its closest existing anchor by
  /// xLeft. When two or more header words map to the same anchor, the
  /// closest one keeps the anchor as its label and the other words get
  /// new synthetic anchors at their own xLeft — that's how a column
  /// like "Uscite" (debits, empty in this report) gets its own slot.
  ///
  /// Synthetic anchors carry the `_ColRole.middle` role since they're
  /// neither date nor amount; downstream code only relies on xLeft / xLo
  /// / xHi for layout, not the role tag.
  static List<_ColAnchor> _augmentAnchorsWithHeader(
    List<_ColAnchor> dataAnchors,
    _Line headerLine,
    double charWidth,
  ) {
    final headerFrags = headerLine.fragments.where((f) => f.text.trim().isNotEmpty).toList();
    if (headerFrags.isEmpty || dataAnchors.isEmpty) return dataAnchors;

    // Group header words by their closest data anchor.
    final byAnchor = <int, List<PdfFragment>>{};
    for (final f in headerFrags) {
      var bestIdx = 0;
      var bestDist = (f.xCenter - dataAnchors[0].xLeft).abs();
      for (var k = 1; k < dataAnchors.length; k++) {
        final d = (f.xCenter - dataAnchors[k].xLeft).abs();
        if (d < bestDist) {
          bestIdx = k;
          bestDist = d;
        }
      }
      byAnchor.putIfAbsent(bestIdx, () => <PdfFragment>[]).add(f);
    }

    // For each anchor with N words, add N-1 synthetic anchors at the
    // header words farthest from the original anchor's xLeft.
    final synthetic = <_ColAnchor>[];
    for (final entry in byAnchor.entries) {
      final anchor = dataAnchors[entry.key];
      final words = entry.value;
      if (words.length < 2) continue;
      // Closest word stays mapped to the original anchor.
      final closest = words.reduce((a, b) => (a.xCenter - anchor.xLeft).abs() < (b.xCenter - anchor.xLeft).abs() ? a : b);
      for (final w in words) {
        if (identical(w, closest)) continue;
        synthetic.add(
          _ColAnchor(
            role: _ColRole.middle,
            xLeft: w.xCenter,
            xLo: w.left - charWidth,
            xHi: w.right + charWidth,
          ),
        );
      }
    }
    if (synthetic.isEmpty) return dataAnchors;
    return [...dataAnchors, ...synthetic]..sort((a, b) => a.xLeft.compareTo(b.xLeft));
  }

  // ────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────

  /// Stricter than [dateparse.tryParseDate]: rejects pure numeric strings
  /// of length 10–13 (the epoch path), which are indistinguishable from
  /// account numbers in transaction PDFs and would corrupt the date anchor.
  static bool _looksLikeDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    if (RegExp(r'^\d{10,13}$').hasMatch(s)) return false;
    return dateparse.tryParseDate(s) != null;
  }

  /// Lenient cell-level date detection. Splits on whitespace and tests
  /// every consecutive 1- to 3-token window for a parseable date. This
  /// matches a row that says "Totale Gennaio 2026" or "Date: 12/2024" —
  /// the cell as a whole doesn't parse but contains a clear date.
  /// Used only for row validation, never for fragment-level anchoring.
  static bool _cellHasDate(String cell) {
    final s = cell.trim();
    if (s.isEmpty) return false;
    if (_looksLikeDate(s)) return true;
    final tokens = s.split(RegExp(r'\s+'));
    for (var i = 0; i < tokens.length; i++) {
      final maxJ = (i + 3 <= tokens.length) ? i + 3 : tokens.length;
      for (var j = i; j < maxJ; j++) {
        if (_looksLikeDate(tokens.sublist(i, j + 1).join(' '))) return true;
      }
    }
    return false;
  }

  static double? _tryAnyLocaleAmount(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    // A pure word like "Total" or "Saldo" would never parse, but a date
    // string can sneak through (e.g. "2024" parses as 2024.0). Reject any
    // value that looks like a date first.
    if (_looksLikeDate(s)) return null;
    for (final l in candidateLocales) {
      final v = amt.tryParseAmount(s, locale: l);
      if (v != null) return v;
    }
    return null;
  }

  static double _medianCharWidth(List<PdfFragment> fragments) {
    final widths = <double>[];
    for (final f in fragments) {
      final n = f.text.length;
      if (n == 0) continue;
      widths.add(f.width / n);
    }
    if (widths.isEmpty) return 4.0;
    widths.sort();
    return widths[widths.length ~/ 2];
  }

  static double _medianLineHeight(List<PdfFragment> fragments) {
    final heights = fragments.map((f) => f.height).where((h) => h > 0).toList();
    if (heights.isEmpty) return 10.0;
    heights.sort();
    return heights[heights.length ~/ 2];
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  static bool _lineHasDateInBand(_Line line, _ColAnchor anchor) {
    for (final p in _findDatesInLine(line)) {
      if (_xInBand(p.xCenter, anchor)) return true;
    }
    return false;
  }

  static bool _xInBand(double x, _ColAnchor anchor) => x >= anchor.xLo && x <= anchor.xHi;

  static String _safeCell(List<String> row, int index) => (index >= 0 && index < row.length) ? row[index] : '';

  /// 1D agglomerative clustering: sort, merge consecutive points whose gap
  /// is below [mergeThreshold]. Returns clusters with min/max/center and
  /// member count.
  static List<_Cluster1D> _cluster1D(
    List<double> values, {
    required double mergeThreshold,
  }) {
    if (values.isEmpty) return const [];
    final sorted = [...values]..sort();
    final clusters = <_Cluster1D>[];
    var lo = sorted.first;
    var hi = sorted.first;
    var count = 1;
    var sum = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final v = sorted[i];
      if (v - hi <= mergeThreshold) {
        hi = v;
        count++;
        sum += v;
      } else {
        clusters.add(_Cluster1D(lo: lo, hi: hi, center: sum / count, count: count));
        lo = v;
        hi = v;
        count = 1;
        sum = v;
      }
    }
    clusters.add(_Cluster1D(lo: lo, hi: hi, center: sum / count, count: count));
    return clusters;
  }
}
