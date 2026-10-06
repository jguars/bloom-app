import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/sfx.dart';
import '../app/theme.dart';

/// The currency glyph: one pad, four toes.
class PawIcon extends StatelessWidget {
  const PawIcon({super.key, this.size = 22, this.color = BloomColors.mustard});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _PawPainter(color));
}

class _PawPainter extends CustomPainter {
  _PawPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()..color = color;
    canvas.drawOval(Rect.fromCenter(center: Offset(12 * s, 16 * s), width: 10.4 * s, height: 8.8 * s), p);
    for (final c in const [Offset(5.6, 10.4), Offset(9.4, 6.6), Offset(14.6, 6.6), Offset(18.4, 10.4)]) {
      canvas.drawCircle(c * s, 2.3 * s, p);
    }
  }

  @override
  bool shouldRepaint(_PawPainter old) => old.color != color;
}

/// Paws balance. Counts up to a new value and bumps when it changes.
class PawChip extends StatefulWidget {
  const PawChip({super.key, required this.paws});
  final int paws;

  @override
  State<PawChip> createState() => PawChipState();
}

class PawChipState extends State<PawChip> with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late int _from = widget.paws;

  @override
  void didUpdateWidget(PawChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paws != widget.paws) {
      if (widget.paws > oldWidget.paws) SfxPlayer.instance.play(Sfx.coin, volume: .8);
      _from = oldWidget.paws;
      _bump.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  static String fmt(int n) {
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return (n < 0 ? '−' : '') + b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bump,
      builder: (context, child) {
        final t = _bump.value;
        final scale = 1 + 0.22 * (t < .35 ? Curves.easeOut.transform(t / .35) : 1 - Curves.easeInOut.transform((t - .35) / .65));
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
        decoration: BoxDecoration(
          color: BloomColors.surface,
          borderRadius: BorderRadius.circular(BloomSpace.rPill),
          boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1)), BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const PawIcon(),
          const SizedBox(width: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _from.toDouble(), end: widget.paws.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(fmt(v.round()), style: BloomText.number.copyWith(fontSize: 17, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]),
      ),
    );
  }
}

/// "+30" chip used in celebrations and for flying paws.
class EarnChip extends StatelessWidget {
  const EarnChip({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
        decoration: BoxDecoration(color: BloomColors.mustardSoft, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const PawIcon(color: BloomColors.ink, size: 20),
          const SizedBox(width: 6),
          Text(text, style: BloomText.number.copyWith(fontSize: 16)),
        ]),
      );
}

/// Spring pop for anything appearing.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final total = delay + const Duration(milliseconds: 520);
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, child) {
        final t = ((v - start) / (1 - start)).clamp(0.0, 1.0);
        final s = BloomMotion.pop.transform(t);
        return Opacity(opacity: Curves.easeOut.transform(t), child: Transform.scale(scale: 0.6 + 0.4 * s, child: child));
      },
      child: child,
    );
  }
}

/// Rises 16px and fades in, after [delay].
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final total = delay + const Duration(milliseconds: 520);
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, child) {
        final t = ((v - start) / (1 - start)).clamp(0.0, 1.0);
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.translate(offset: Offset(0, 16 * (1 - BloomMotion.spring.transform(t))), child: child),
        );
      },
      child: child,
    );
  }
}
