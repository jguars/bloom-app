import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Flat drawings of everything in the Shop (gear, outfits and decor), on an 80×60 grid.
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
      // Outfits.
      case 'o_sweatband':
        canvas.drawRRect(rr(12, 22, 56, 16, 8), f(BloomColors.coral));
        canvas.drawRRect(rr(12, 28, 56, 4, 2), f(BloomColors.surface));
      case 'o_bandana':
        canvas.drawPath(Path()..moveTo(10, 16)..quadraticBezierTo(40, 26, 70, 16)..lineTo(40, 52)..close(), f(BloomColors.clay));
        for (final o in const [Offset(30, 24), Offset(46, 26), Offset(38, 36), Offset(52, 20)]) {
          canvas.drawCircle(o, 2.2, f(BloomColors.surface));
        }
      case 'o_glasses':
        canvas.drawCircle(const Offset(26, 32), 12, s(BloomColors.ink, 3.5));
        canvas.drawCircle(const Offset(54, 32), 12, s(BloomColors.ink, 3.5));
        canvas.drawLine(const Offset(38, 30), const Offset(42, 30), s(BloomColors.ink, 3.5));
        canvas.drawCircle(const Offset(26, 32), 9, f(BloomColors.sky));
        canvas.drawCircle(const Offset(54, 32), 9, f(BloomColors.sky));
      case 'o_bowtie':
        canvas.drawPath(Path()..moveTo(40, 30)..lineTo(14, 16)..lineTo(14, 44)..close(), f(BloomColors.coral));
        canvas.drawPath(Path()..moveTo(40, 30)..lineTo(66, 16)..lineTo(66, 44)..close(), f(BloomColors.coral));
        canvas.drawRRect(rr(34, 23, 12, 14, 4), f(BloomColors.clay));
      case 'o_cap':
        canvas.drawPath(Path()..moveTo(14, 40)..quadraticBezierTo(34, 4, 54, 40)..close(), f(BloomColors.mustard));
        canvas.drawPath(Path()..moveTo(48, 36)..lineTo(74, 40)..quadraticBezierTo(70, 46, 48, 44)..close(), f(BloomColors.mustardPress));
        canvas.drawCircle(const Offset(34, 15), 3, f(BloomColors.mustardPress));
      case 'o_shades':
        canvas.drawRRect(rr(8, 22, 28, 18, 8), f(BloomColors.ink));
        canvas.drawRRect(rr(44, 22, 28, 18, 8), f(BloomColors.ink));
        canvas.drawLine(const Offset(36, 28), const Offset(44, 28), s(BloomColors.ink, 4));
        canvas.drawLine(const Offset(14, 27), const Offset(20, 27), s(BloomColors.inkMuted, 2.5));
        canvas.drawLine(const Offset(50, 27), const Offset(56, 27), s(BloomColors.inkMuted, 2.5));
      case 'o_beanie':
        canvas.drawPath(Path()..moveTo(14, 44)..quadraticBezierTo(40, -2, 66, 44)..close(), f(BloomColors.skyDeep));
        canvas.drawRRect(rr(12, 40, 56, 12, 6), f(const Color(0xFF284F60)));
        canvas.drawCircle(const Offset(40, 12), 7, f(BloomColors.surface));
      case 'o_scarf':
        canvas.drawRRect(rr(8, 16, 64, 14, 7), f(BloomColors.mustard));
        canvas.drawRRect(rr(46, 22, 14, 32, 5), f(BloomColors.mustardPress));
        for (var x = 48.0; x < 60; x += 4) {
          canvas.drawLine(Offset(x, 54), Offset(x, 58), s(BloomColors.mustardPress, 2));
        }
      case 'o_crown':
        canvas.drawArc(const Rect.fromLTWH(12, 18, 56, 34), 3.3, 2.8, false, s(BloomColors.sageDeep, 4));
        for (final (o, c) in const [(Offset(18, 30), BloomColors.coral), (Offset(30, 21), BloomColors.mustard), (Offset(40, 18), BloomColors.blush), (Offset(50, 21), BloomColors.mustard), (Offset(62, 30), BloomColors.coral)]) {
          canvas.drawCircle(o, 6, f(c));
          canvas.drawCircle(o, 2, f(BloomColors.surface));
        }
      case 'o_hoodie':
        canvas.drawPath(Path()..moveTo(22, 14)..lineTo(58, 14)..lineTo(72, 30)..lineTo(64, 36)..lineTo(60, 32)..lineTo(60, 54)..lineTo(20, 54)..lineTo(20, 32)..lineTo(16, 36)..lineTo(8, 30)..close(), f(BloomColors.clay));
        canvas.drawArc(const Rect.fromLTWH(28, 6, 24, 20), 0, 3.14159, true, f(BloomColors.clayDeep));
        canvas.drawRRect(rr(30, 38, 20, 10, 4), f(BloomColors.clayDeep));
      case 'o_tracksuit':
        canvas.drawPath(Path()..moveTo(22, 12)..lineTo(58, 12)..lineTo(72, 30)..lineTo(64, 36)..lineTo(60, 32)..lineTo(60, 54)..lineTo(20, 54)..lineTo(20, 32)..lineTo(16, 36)..lineTo(8, 30)..close(), f(BloomColors.forest));
        canvas.drawLine(const Offset(40, 14), const Offset(40, 54), s(BloomColors.mustard, 2.5));
        canvas.drawLine(const Offset(12, 28), const Offset(22, 16), s(BloomColors.surface, 3));
        canvas.drawLine(const Offset(68, 28), const Offset(58, 16), s(BloomColors.surface, 3));
      // Room decor.
      case 'd_plant':
        canvas.drawPath(Path()..moveTo(26, 36)..lineTo(54, 36)..lineTo(50, 56)..lineTo(30, 56)..close(), f(BloomColors.clay));
        for (final a in const [-.7, -.2, .3, .8]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(40 + 26 * a, 22 - 8 * (1 - a.abs())), width: 14, height: 24), f(BloomColors.sageDeep));
        }
      case 'd_poster':
        canvas.drawRRect(rr(18, 6, 44, 50, 3), f(BloomColors.surface));
        canvas.drawRRect(rr(18, 6, 44, 50, 3), s(BloomColors.line, 2));
        canvas.drawCircle(const Offset(48, 20), 6, f(BloomColors.mustard));
        canvas.drawPath(Path()..moveTo(22, 50)..lineTo(36, 28)..lineTo(46, 40)..lineTo(52, 34)..lineTo(58, 50)..close(), f(BloomColors.sage));
      case 'd_rug':
        canvas.drawOval(const Rect.fromLTWH(6, 24, 68, 28), f(BloomColors.blush));
        canvas.drawOval(const Rect.fromLTWH(16, 29, 48, 18), f(BloomColors.coral));
        canvas.drawOval(const Rect.fromLTWH(28, 34, 24, 8), f(BloomColors.blush));
      case 'd_lamp':
        canvas.drawPath(Path()..moveTo(26, 26)..lineTo(54, 26)..lineTo(46, 8)..lineTo(34, 8)..close(), f(BloomColors.mustard));
        canvas.drawLine(const Offset(40, 26), const Offset(40, 52), s(BloomColors.inkMuted, 3.5));
        canvas.drawRRect(rr(28, 50, 24, 6, 3), f(BloomColors.inkMuted));
        canvas.drawCircle(const Offset(40, 30), 12, f(BloomColors.mustardSoft.withValues(alpha: .5)));
      case 'd_beanbag':
        canvas.drawPath(Path()..moveTo(10, 54)..quadraticBezierTo(4, 22, 36, 16)..quadraticBezierTo(74, 12, 72, 54)..close(), f(BloomColors.sageDeep));
        canvas.drawPath(Path()..moveTo(24, 40)..quadraticBezierTo(40, 30, 58, 40), s(BloomColors.forestPress, 3));
      case 'd_cattree':
        canvas.drawRRect(rr(36, 12, 8, 42, 3), f(const Color(0xFFC8A27A)));
        canvas.drawRRect(rr(14, 50, 52, 6, 3), f(BloomColors.clay));
        canvas.drawRRect(rr(16, 32, 26, 6, 3), f(BloomColors.clay));
        canvas.drawRRect(rr(40, 18, 26, 6, 3), f(BloomColors.clay));
        canvas.drawCircle(const Offset(22, 40), 4, f(BloomColors.mustard));
      case 'd_aquarium':
        canvas.drawRRect(rr(10, 12, 60, 40, 5), f(BloomColors.sky));
        canvas.drawRRect(rr(10, 12, 60, 40, 5), s(BloomColors.skyDeep, 3));
        canvas.drawOval(const Rect.fromLTWH(26, 26, 16, 10), f(BloomColors.coral));
        canvas.drawPath(Path()..moveTo(42, 31)..lineTo(50, 25)..lineTo(50, 37)..close(), f(BloomColors.coral));
        canvas.drawLine(const Offset(58, 52), const Offset(58, 34), s(BloomColors.sageDeep, 3));
        canvas.drawCircle(const Offset(22, 20), 2, f(BloomColors.surface));
      case 'd_record':
        canvas.drawRRect(rr(8, 24, 64, 30, 5), f(BloomColors.clayDeep));
        canvas.drawOval(const Rect.fromLTWH(14, 18, 42, 18), f(BloomColors.ink));
        canvas.drawOval(const Rect.fromLTWH(29, 24, 12, 6), f(BloomColors.coral));
        canvas.drawLine(const Offset(64, 20), const Offset(46, 30), s(BloomColors.inkMuted, 3));
      case 'bar':
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
