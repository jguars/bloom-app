import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Flat drawings of each piece of gear, matching the mockups (80×60 grid).
class GearArt extends StatelessWidget {
  const GearArt({super.key, required this.id, this.width = 80});
  final String id;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(width, width * .75), painter: _GearPainter(id));
}

class _GearPainter extends CustomPainter {
  _GearPainter(this.id);
  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 80);
    Paint f(Color c) => Paint()..color = c;
    Paint s(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    RRect rr(double x, double y, double w, double h, double r) => RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));
    switch (id) {
      case 'mat':
        canvas.drawRRect(rr(8, 30, 58, 16, 8), f(BloomColors.blush));
        canvas.drawCircle(const Offset(64, 30), 12, f(const Color(0xFFD79E8B)));
        canvas.drawCircle(const Offset(64, 30), 5, f(BloomColors.blush));
      case 'rope':
        canvas.drawPath(Path()..moveTo(18, 18)..cubicTo(22, 48, 58, 52, 62, 18), s(BloomColors.sageDeep, 4));
        canvas.drawRRect(rr(12, 6, 10, 18, 5), f(BloomColors.mustard));
        canvas.drawRRect(rr(58, 6, 10, 18, 5), f(BloomColors.mustard));
      case 'dumbbells':
        canvas.drawRRect(rr(26, 27, 28, 6, 3), f(BloomColors.inkMuted));
        canvas.drawRRect(rr(14, 16, 14, 28, 6), f(BloomColors.clay));
        canvas.drawRRect(rr(52, 16, 14, 28, 6), f(BloomColors.clay));
      case 'kettlebell':
        canvas.drawArc(const Rect.fromLTWH(30, 12, 20, 20), 3.14159, 3.14159, false, s(BloomColors.ink, 5));
        canvas.drawOval(const Rect.fromLTWH(23, 23, 34, 30), f(BloomColors.ink));
      case 'treadmill':
        canvas.drawLine(const Offset(12, 46), const Offset(64, 38), s(BloomColors.inkMuted, 8));
        canvas.drawLine(const Offset(58, 39), const Offset(62, 13), s(BloomColors.sageDeep, 5));
        canvas.drawRRect(rr(54, 8, 18, 8, 4), f(BloomColors.sage));
      default:
        canvas.drawLine(const Offset(18, 10), const Offset(18, 52), s(BloomColors.sageDeep, 5));
        canvas.drawLine(const Offset(62, 10), const Offset(62, 52), s(BloomColors.sageDeep, 5));
        canvas.drawLine(const Offset(18, 24), const Offset(62, 24), s(BloomColors.sageDeep, 5));
        canvas.drawRRect(rr(8, 18, 10, 12, 4), f(BloomColors.mustard));
        canvas.drawRRect(rr(62, 18, 10, 12, 4), f(BloomColors.mustard));
    }
  }

  @override
  bool shouldRepaint(_GearPainter old) => old.id != id;
}
