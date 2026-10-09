import 'package:flutter/material.dart';

/// A footnote under a figure, saying what the figure leaves out: small, muted
/// text. It carries counts, not amounts — shape, not magnitude — so privacy
/// mode leaves it readable.
class Footnote extends StatelessWidget {
  final String text;

  const Footnote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }
}
