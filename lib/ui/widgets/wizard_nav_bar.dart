import 'package:flutter/material.dart';

/// The bottom bar of a wizard step (the import wizard's steps, the
/// classification card), so their actions look and sit alike: the step's
/// primary action as a filled button at the end, an optional secondary action
/// as an outlined button before it, and an optional [leading] widget (e.g.
/// why the primary action is off) taking the room before them.
class WizardNavBar extends StatelessWidget {
  const WizardNavBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.primaryKey,
    this.primaryBusy = false,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryIcon,
    this.secondaryKey,
    this.leading,
  });

  final String primaryLabel;

  /// Null disables the primary button.
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;
  final Key? primaryKey;

  /// The primary action is running: a progress indicator stands in for its
  /// icon (the caller turns the buttons off meanwhile).
  final bool primaryBusy;

  /// No secondary button when null.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? secondaryIcon;
  final Key? secondaryKey;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = this.secondaryLabel;
    final buttons = Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (secondaryLabel != null)
          OutlinedButton.icon(
            key: secondaryKey,
            icon: secondaryIcon == null ? null : Icon(secondaryIcon),
            label: Text(secondaryLabel),
            onPressed: onSecondary,
          ),
        FilledButton.icon(
          key: primaryKey,
          icon: primaryBusy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : primaryIcon == null
              ? null
              : Icon(primaryIcon),
          label: Text(primaryLabel),
          onPressed: onPrimary,
        ),
      ],
    );
    final leading = this.leading;
    if (leading == null) return Align(alignment: AlignmentDirectional.centerEnd, child: buttons);
    return Row(
      children: [
        Expanded(child: leading),
        const SizedBox(width: 8),
        buttons,
      ],
    );
  }
}
