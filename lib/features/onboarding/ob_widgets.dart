import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../ui/paw.dart';

/// Where Clover's face sits in each scene, for the round avatar: the image's
/// pixel width, the face centre and how many source pixels the circle spans.
const _faces = {
  'porch': ('assets/scenes/porch.jpg', 914.0, 498.0, 620.0, 157.0),
  'living': ('assets/scenes/living.jpg', 1066.0, 622.0, 668.0, 130.0),
  'hall': ('assets/scenes/hallway.jpg', 1100.0, 492.0, 575.0, 120.0),
};

/// Clover's face cropped from a scene, bobbing gently.
class CloverFace extends StatefulWidget {
  const CloverFace({super.key, this.scene = 'living', this.size = 72});
  final String scene;
  final double size;
  @override
  State<CloverFace> createState() => _CloverFaceState();
}

class _CloverFaceState extends State<CloverFace> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (asset, imgW, cx, cy, span) = _faces[widget.scene]!;
    final k = widget.size / span;
    return PopIn(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(offset: Offset(0, -2.5 * math.sin(_c.value * 2 * math.pi)), child: child),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: BloomColors.oat, boxShadow: [BoxShadow(color: Color(0x1F2E3826), blurRadius: 12, offset: Offset(0, 4))]),
          clipBehavior: Clip.antiAlias,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(left: widget.size / 2 - cx * k, top: widget.size / 2 - cy * k, width: imgW * k, child: Image.asset(asset, fit: BoxFit.fitWidth)),
          ]),
        ),
      ),
    );
  }
}

/// Clover's face with a line beside it that pops whenever it changes.
class CloverSays extends StatelessWidget {
  const CloverSays({super.key, required this.line, this.scene = 'living'});
  final String line, scene;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        CloverFace(scene: scene),
        const SizedBox(width: 10),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: BloomMotion.pop,
              transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(a), alignment: Alignment.bottomLeft, child: FadeTransition(opacity: a, child: c)),
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
              child: Container(
                key: ValueKey(line),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: BloomColors.surface,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(6)),
                  boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 2)), BoxShadow(color: Color(0x14403A1E), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Text(line, style: BloomText.bubble.copyWith(fontSize: 15, height: 20 / 15)),
              ),
            ),
          ),
        ),
      ]);
}

/// The big question and its helper line.
class ObQuestion extends StatelessWidget {
  const ObQuestion(this.q, {super.key, this.help});
  final String q;
  final String? help;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(q, style: BloomText.display.copyWith(fontSize: 27, height: 33 / 27)),
        if (help != null) ...[const SizedBox(height: 6), Text(help!, style: BloomText.bodyMuted.copyWith(fontSize: 15, height: 21 / 15))],
      ]);
}

/// A choice tile: radio or checkbox. Selecting springs it and fills it
/// forest-soft.
class ObChoice extends StatelessWidget {
  const ObChoice({super.key, required this.label, required this.selected, required this.onTap, this.sub, this.multi = false, this.leading, this.trailing});
  final String label;
  final String? sub;
  final bool selected, multi;
  final VoidCallback onTap;

  /// A picture in place of the radio mark (a tick shows on the right once picked).
  final Widget? leading;

  /// Something at the end of the row (a goal date).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final mark = multi
        ? AnimatedContainer(
            duration: BloomMotion.fast,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? BloomColors.forest : BloomColors.surface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: selected ? BloomColors.forest : BloomColors.lineStrong, width: 2),
            ),
            child: selected ? const Icon(Icons.check_rounded, size: 16, color: BloomColors.onForest) : null,
          )
        : AnimatedContainer(
            duration: BloomMotion.fast,
            width: 24,
            height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? BloomColors.forest : BloomColors.lineStrong, width: selected ? 7 : 2), color: BloomColors.surface),
          );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () {
          Feel.selectionClick();
          onTap();
        },
        child: TweenAnimationBuilder<double>(
          key: ValueKey(selected),
          tween: Tween(begin: selected ? .96 : 1, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: BloomMotion.pop,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: AnimatedContainer(
            duration: BloomMotion.base,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? BloomColors.forestSoft : BloomColors.surface,
              borderRadius: BorderRadius.circular(BloomSpace.rMd),
              border: Border.all(color: selected ? BloomColors.forest : BloomColors.line, width: 2),
              boxShadow: [BoxShadow(color: selected ? BloomColors.sage : BloomColors.line, offset: const Offset(0, 3))],
            ),
            child: Row(children: [
              leading ?? mark,
              SizedBox(width: leading == null ? 14 : 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: BloomText.headline.copyWith(fontSize: 16, height: 22 / 16, color: selected ? BloomColors.forest : BloomColors.ink)),
                  if (sub != null) Text(sub!, style: BloomText.caption),
                ]),
              ),
              ?trailing,
              if (leading != null)
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: BloomMotion.pop,
                  child: const Icon(Icons.check_circle_rounded, color: BloomColors.forest, size: 24),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Back button and the step bar along the top.
class ObTopBar extends StatelessWidget {
  const ObTopBar({super.key, required this.step, required this.total, required this.onBack});
  final int step, total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(children: [
        Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            onTap: onBack,
            child: const SizedBox(width: 44, height: 44, child: Icon(Icons.chevron_left_rounded, size: 30, color: BloomColors.ink)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Semantics(
            label: 'Step $step of $total',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Stack(children: [
                  const Positioned.fill(child: ColoredBox(color: BloomColors.paperSunk)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: step / total),
                    duration: const Duration(milliseconds: 520),
                    curve: BloomMotion.spring,
                    builder: (context, v, _) => FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      child: Container(decoration: BoxDecoration(color: BloomColors.forest, borderRadius: BorderRadius.circular(6))),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
      ]);
}
