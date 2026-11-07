import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/tables.dart';
import '../../services/providers/providers.dart';
import '../../utils/privacy_slots.dart';

export '../../utils/privacy_slots.dart';

/// Standard blur sigma applied across the app whenever privacy mode is on.
/// Centralised so every leaf has identical visual treatment.
const double kPrivacyBlurSigma = 6;

/// Blurs [child] when [isPrivate] is true: the one treatment every privacy
/// wrapper applies. Use it directly only where the privacy flag is handed down
/// by the caller (the charts take an `isPrivate` flag) instead of being read
/// from [privacyModeProvider]; everywhere else use [PrivacyBlur] or
/// [PrivacyText] — a figure private only in some cases passes
/// [PrivacyText.masked].
class PrivacyMask extends StatelessWidget {
  final bool isPrivate;
  final Widget child;

  const PrivacyMask({required this.isPrivate, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    if (!isPrivate) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: kPrivacyBlurSigma,
        sigmaY: kPrivacyBlurSigma,
      ),
      child: child,
    );
  }
}

/// Conditionally blurs an arbitrary [child] when privacy mode is active.
/// Use directly when wrapping non-text content (rich text, rows, table
/// cells, …); for plain strings prefer [PrivacyText] which keeps the call
/// site one-liner.
class PrivacyBlur extends ConsumerWidget {
  final Widget child;

  const PrivacyBlur({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PrivacyMask(isPrivate: ref.watch(privacyModeProvider), child: child);
}

/// A position-size string, blurred in privacy mode — unless [masked] is false.
class PrivacyText extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Whether [text] is position size. False renders the same plain text in
  /// privacy mode too: for a figure that is private only in some cases (a
  /// unit price, see [unitPriceIsPrivate]), decided by the caller.
  final bool masked;

  const PrivacyText(this.text, {this.style, this.textAlign, this.maxLines, this.overflow, this.masked = true, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PrivacyMask(
    isPrivate: masked && ref.watch(privacyModeProvider),
    child: Text(text, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow),
  );
}

/// A position-size figure inline in a [Text.rich]: blurred in privacy mode
/// exactly like [PrivacyText], while the spans around it stay readable.
WidgetSpan privacyFigureSpan(String figure, {TextStyle? style}) => WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  // The paragraph already scales inline widgets with its text; keep the
  // figure from being scaled a second time.
  child: MediaQuery.withNoTextScaling(child: PrivacyText(figure, style: style)),
);

/// A sentence that quotes position-size figures between readable words.
///
/// [template] is the localized sentence built with [privacySlot] markers where
/// the figures go; [figures] fills them in. Outside privacy mode it renders
/// the plain sentence. In privacy mode only the figures blur: the words,
/// counts, dates and percentages around them stay readable — blurring the
/// whole sentence would hide exactly what privacy mode is meant to keep.
class PrivacySentence extends ConsumerWidget {
  final String template;
  final List<String> figures;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PrivacySentence(
    this.template, {
    required this.figures,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privacyModeProvider);
    final parts = splitPrivacySlots(template);
    if (!isPrivate) {
      return Text(
        [for (final (:words, :slot) in parts) slot == null ? words : figures[slot]].join(),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          for (final (:words, :slot) in parts) slot == null ? TextSpan(text: words) : privacyFigureSpan(figures[slot], style: style),
        ],
      ),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Whether a unit price must be masked like a position figure.
///
/// A market price is public data — identical for every holder — and stays
/// readable. A manually valued (event-driven) asset has no market price: its
/// per-unit figure is the user's own revaluation divided by the units held,
/// and for a single-unit holding it IS the position value. Unless the units
/// are the money put in ([unitsAreMoney], see `AssetStats.unitsAreMoney`):
/// the price is then a growth index (1.04: each euro put in is worth 1.04),
/// which says nothing of how much is held.
bool unitPriceIsPrivate(ValuationMethod valuation, {bool unitsAreMoney = false}) => valuation != ValuationMethod.marketPrice && !unitsAreMoney;
