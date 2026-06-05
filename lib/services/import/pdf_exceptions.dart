/// Explicit failure modes when ingesting a PDF for import. Each subclass
/// maps to a distinct localized message in `AppStrings`. Per CLAUDE.md, we
/// never silently fall back: if any of these triggers, the wizard surfaces
/// the error and writes nothing to the database.
sealed class PdfImportException implements Exception {
  final String message;
  const PdfImportException(this.message);
  @override
  String toString() => '$runtimeType: $message';
}

/// PDF carries no extractable text layer (likely a scan or image-only export).
class PdfNoTextLayerException extends PdfImportException {
  const PdfNoTextLayerException(super.message);
}

/// PDF is password-protected. Pdfrx surfaces this through `PdfPasswordException`;
/// we wrap it so the UI layer pattern-matches a single hierarchy.
class PdfEncryptedException extends PdfImportException {
  const PdfEncryptedException(super.message);
}

/// Text was extracted but the bytes are mostly Private-Use-Area glyph IDs,
/// which means the producer omitted or broke the `ToUnicode` CMap. Reading
/// further would emit garbage rows.
class PdfUnreadableTextException extends PdfImportException {
  const PdfUnreadableTextException(super.message);
}

/// The text layer is readable but the algorithm could not locate a
/// transaction table that satisfies the date-anchor, amount-anchor, volume,
/// and per-row validation invariants.
class PdfTableNotDetectedException extends PdfImportException {
  const PdfTableNotDetectedException(super.message);
}
