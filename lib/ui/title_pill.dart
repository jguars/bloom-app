import 'package:flutter/material.dart';

import '../app/feel.dart';
import '../app/theme.dart';

/// The one button that sits at the right end of a page title (Plan's photo check, the Shop's Plus, the Progress
/// streak, Today's craving help): a 44-tall sky pill with a white disc holding the icon, then a short label.
class TitlePill extends StatelessWidget {
  const TitlePill({super.key, required this.icon, required this.label, required this.semantics, required this.onTap});

  /// Sits in the white disc (an [Icon] in [iconColor], or a small painted mark).
  final Widget icon;
  final String label, semantics;
  final VoidCallback onTap;

  static const iconSize = 19.0, iconColor = BloomColors.skyDeep;

  /// A painted icon's size in the white disc.
  static const artSize = 26.0;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantics,
        child: GestureDetector(
          onTap: () {
            Feel.selectionClick();
            onTap();
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
            decoration: BoxDecoration(
              color: BloomColors.skyDeep,
              borderRadius: BorderRadius.circular(BloomSpace.rPill),
              boxShadow: const [BoxShadow(color: Color(0x3324485A), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle),
                child: icon,
              ),
              const SizedBox(width: 8),
              Text(label, style: BloomText.button.copyWith(fontSize: 14, color: BloomColors.surface)),
            ]),
          ),
        ),
      );
}
