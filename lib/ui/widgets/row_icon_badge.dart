import 'package:flutter/material.dart';

/// The round icon a list row starts with: [icon] in [color] on a [tint] of
/// that color. It always takes the same [extent] square, tappable or not, so
/// every row of a list starts its icon and its title at the same place: a
/// list tile starts its title right after its leading widget, so a badge any
/// wider than the others pushes its row's icon and title off theirs.
///
/// With [onTap] it is a button, named by [tooltip], rippling as a circle over
/// the whole square. Without it the badge takes no gesture: a tap on it is a
/// tap on its row.
class RowIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  /// Opacity of the background disc, a tint of [color].
  final double tint;
  final VoidCallback? onTap;
  final String? tooltip;

  const RowIconBadge({required this.icon, required this.color, required this.tint, this.onTap, this.tooltip, super.key});

  /// The side of the square every badge takes: a tap target around the disc.
  static const double extent = 40;

  /// The radius of the disc drawn in the middle of the square.
  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final badge = SizedBox.square(
      dimension: extent,
      child: Center(
        child: CircleAvatar(
          radius: radius,
          backgroundColor: color.withValues(alpha: tint),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
    if (onTap == null) return badge;
    final button = InkResponse(onTap: onTap, radius: extent / 2, child: badge);
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
