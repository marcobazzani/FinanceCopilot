import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/providers/providers.dart';

/// Standard blur sigma applied across the app whenever privacy mode is on.
/// Centralised so every leaf has identical visual treatment.
const double kPrivacyBlurSigma = 6;

/// Conditionally blurs an arbitrary [child] when privacy mode is active.
/// Use directly when wrapping non-text content (rich text, rows, table
/// cells, …); for plain strings prefer [PrivacyText] which keeps the call
/// site one-liner.
class PrivacyBlur extends ConsumerWidget {
  final Widget child;

  const PrivacyBlur({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privacyModeProvider);
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

class PrivacyText extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PrivacyText(this.text, {this.style, this.textAlign, this.maxLines, this.overflow, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privacyModeProvider);
    final child = Text(text, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
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
