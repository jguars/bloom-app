import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A small flat Clover standing front-on, drawn from the mascot rules: an oat
/// bean, sage noodle limbs (darker far side), dark ears, a mustard tail, the
/// flower behind her right ear, and closed happy eyes. [bodyMass] widens only
/// the bean (100 = softest, 125% of fit; 0 = fit).
class CloverMini extends StatelessWidget {
  const CloverMini({super.key, required this.bodyMass, this.size = 72, this.dim = false});
  final double bodyMass;
  final double size;

  /// Faded, for flags not reached yet.
  final bool dim;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: bodyMass),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (context, m, _) => Opacity(
          opacity: dim ? .45 : 1,
          child: CustomPaint(size: Size(size, size * 1.1), painter: _CloverPainter(m)),
        ),
      );
}

class _CloverPainter extends CustomPainter {
  _CloverPainter(this.mass);
  final double mass;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 110);
    final w = 1 + .25 * (mass / 100).clamp(0, 1);
    const cx = 50.0;
    final hw2 = 25 * w; // half width at the hips
    const hw1 = 22.0; // half width at the head

    Paint fill(Color c) => Paint()..color = c;
    Paint tube(Color c, double width) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Tail behind everything.
    canvas.drawPath(
      Path()
        ..moveTo(cx + hw2 * .8, 90)
        ..quadraticBezierTo(cx + hw2 + 18, 88, cx + hw2 + 14, 62),
      tube(BloomColors.mustard, 7),
    );
    // Legs and arms; far side darker.
    canvas.drawLine(const Offset(cx - 11, 92), const Offset(cx - 12, 105), tube(BloomColors.sageDeep, 8));
    canvas.drawLine(const Offset(cx + 11, 92), const Offset(cx + 12, 105), tube(BloomColors.sage, 8));
    canvas.drawPath(Path()..moveTo(cx - hw2 * .85, 62)..quadraticBezierTo(cx - hw2 - 10, 70, cx - hw2 - 8, 82), tube(BloomColors.sageDeep, 7));
    canvas.drawPath(Path()..moveTo(cx + hw2 * .85, 62)..quadraticBezierTo(cx + hw2 + 10, 70, cx + hw2 + 8, 82), tube(BloomColors.sage, 7));
    // Ears.
    final ear = Paint()
      ..color = BloomColors.sageDeep
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.fill;
    for (final s in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(cx + s * 21, 34)
        ..lineTo(cx + s * 19, 10)
        ..lineTo(cx + s * 5, 24)
        ..close();
      canvas.drawPath(p, ear);
      canvas.drawPath(p, ear..style = PaintingStyle.stroke);
      ear.style = PaintingStyle.fill;
    }
    // Flower behind her right ear (the viewer's left).
    const fc = Offset(cx - 22, 15);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawCircle(fc + Offset(math.cos(a), math.sin(a)) * 4.2, 3.4, fill(BloomColors.mustard));
    }
    canvas.drawCircle(fc, 2.4, fill(BloomColors.oat));
    // The bean: one shape for head and body, wider at the bottom.
    final bean = Path()
      ..moveTo(cx, 19)
      ..cubicTo(cx + hw1 * 1.15, 19, cx + hw1, 46, cx + hw2 * .96, 70)
      ..cubicTo(cx + hw2 * 1.06, 90, cx + hw2 * .62, 99, cx, 99)
      ..cubicTo(cx - hw2 * .62, 99, cx - hw2 * 1.06, 90, cx - hw2 * .96, 70)
      ..cubicTo(cx - hw1, 46, cx - hw1 * 1.15, 19, cx, 19)
      ..close();
    canvas.drawPath(bean, fill(BloomColors.oat));
    // Face: closed happy crescents, a little w, whiskers.
    final ink = tube(BloomColors.ink, 2.2);
    for (final s in [-1.0, 1.0]) {
      canvas.drawArc(Rect.fromCenter(center: Offset(cx + s * 9, 42), width: 8, height: 7), math.pi, math.pi, false, ink);
      for (final dy in [-2.5, 1.0, 4.5]) {
        canvas.drawLine(Offset(cx + s * 15, 48 + dy * .6), Offset(cx + s * 22, 47 + dy), tube(BloomColors.ink, 1.3));
      }
    }
    canvas.drawPath(
      Path()
        ..moveTo(cx - 4, 48)
        ..quadraticBezierTo(cx - 2, 51.5, cx, 48.5)
        ..quadraticBezierTo(cx + 2, 51.5, cx + 4, 48),
      tube(BloomColors.ink, 1.8),
    );
  }

  @override
  bool shouldRepaint(_CloverPainter old) => old.mass != mass;
}
