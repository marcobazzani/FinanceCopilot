part of 'pdf_table_reconstructor.dart';

// ────────────────────────────────────────────────────────
// Internal types
// ────────────────────────────────────────────────────────

class _Line {
  final int page;
  final List<PdfFragment> fragments;
  final double medianY;
  const _Line({
    required this.page,
    required this.fragments,
    required this.medianY,
  });
}

enum _ColRole { date, amount, balance, middle }

class _ColAnchor {
  final _ColRole role;
  final double xLeft;
  final double xLo;
  final double xHi;
  const _ColAnchor({
    required this.role,
    required this.xLeft,
    required this.xLo,
    required this.xHi,
  });
}

class _FragmentInLine {
  final int lineIndex;
  final PdfFragment fragment;
  const _FragmentInLine({required this.lineIndex, required this.fragment});
}

/// A parseable-date position on a line. May span multiple fragments
/// (e.g. "Gennaio" + "2026") or be a single fragment ("01/2026").
class _DatePos {
  final double left;
  final double right;
  _DatePos({required this.left, required this.right});
  double get xCenter => (left + right) / 2;
}

class _Cluster1D {
  final double lo;
  final double hi;
  final double center;
  final int count;
  const _Cluster1D({
    required this.lo,
    required this.hi,
    required this.center,
    required this.count,
  });
}

/// Output of [PdfTableReconstructor._mergeWraps]: the assembled rows plus
/// the indices of "snapshot" rows — date-less lines that carry only an
/// anchored amount/balance (e.g. a pension statement's "POSIZIONE
/// INDIVIDUALE" opening/closing position). They are emitted as their own
/// rows so the data isn't lost, but excluded from the per-row date
/// validation since they legitimately have no date.
class _MergeResult {
  final List<List<String>> rows;
  final Set<int> snapshotRowIndices;
  const _MergeResult({required this.rows, required this.snapshotRowIndices});
}
