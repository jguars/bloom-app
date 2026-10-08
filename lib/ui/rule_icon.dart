import 'package:flutter/material.dart';

import '../data/plan.dart';

/// A rule's painted icon (`assets/plan/<key>.webp`) on its tile. Keys without art (none today) fall back
/// to the line icon from [planIcons].
class RuleIcon extends StatelessWidget {
  const RuleIcon(this.icon, {super.key, required this.size, this.color, this.dim = false});
  final String icon;
  final double size;

  /// The fallback line icon's colour.
  final Color? color;

  /// Faded, as on a rule that's done for now.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(
      'assets/plan/$icon.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Icon(iconFor(icon), color: color, size: size * .62),
    );
    return dim ? Opacity(opacity: .8, child: art) : art;
  }
}
