import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/providers/providers.dart';

class PrivacyText extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PrivacyText(this.text,
      {this.style, this.textAlign, this.maxLines, this.overflow, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privacyModeProvider);
    final child = Text(text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow);
    if (!isPrivate) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: child,
    );
  }
}
