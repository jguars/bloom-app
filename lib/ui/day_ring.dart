import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Three-segment ring for today's moves. A newly earned segment sweeps in,
/// and the whole ring pops when it fills.
class DayRing extends StatelessWidget {
  const DayRing({super.key, required this.done, this.size = 56});
  final int done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = done.clamp(0, 3);
    return Semantics(
      label: '$d of 3 today',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: d.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) {
          final full = v > 2.98;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: full ? 1 : 0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, pop, child) => Transform.scale(scale: 1 + 0.12 * math.sin(pop * math.pi), child: child),
            child: SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: _RingPainter(v),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$d', style: BloomText.number.copyWith(fontSize: 17, height: 1)),
                    Text('of 3', style: BloomText.caption.copyWith(fontSize: 10, height: 1.1)),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    final track = Paint()
      ..color = BloomColors.paperSunk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final on = Paint()
      ..color = BloomColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    const gap = 0.32;
    const seg = 2 * math.pi / 3;
    for (var i = 0; i < 3; i++) {
      final start = -math.pi / 2 + i * seg + gap / 2;
      canvas.drawArc(rect, start, seg - gap, false, track);
      final fill = (progress - i).clamp(0.0, 1.0);
      if (fill > 0) canvas.drawArc(rect, start, (seg - gap) * fill, false, on);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
