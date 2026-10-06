import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/profile.dart';
import '../data/weight.dart';

/// The user's weigh-ins (solid forest) against the planned pace (dashed
/// sky-deep), drawn in on first show and whenever a weigh-in is added.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.log, required this.units, required this.now, this.height = 170});
  final WeightLog log;
  final Units units;
  final DateTime now;
  final double height;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(log.entries.length),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) => CustomPaint(size: Size(double.infinity, height), painter: _ChartPainter(log, units, now, t)),
      );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.log, this.units, this.now, this.t);
  final WeightLog log;
  final Units units;
  final DateTime now;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final first = log.first;
    if (first == null) return;
    final start = first.at;
    var end = now.isAfter(log.latest!.at) ? now : log.latest!.at;
    if (end.difference(start).inDays < 14) end = start.add(const Duration(days: 14));
    final span = end.difference(start).inMinutes.toDouble();

    final planEnd = log.plannedOn(end)!;
    // The goal only widens the range once it's close, so a far goal doesn't
    // squash the line flat against the top.
    final values = [for (final e in log.entries) e.kg, first.kg, planEnd];
    final goal = log.goalKg;
    if (goal != null && (planEnd - goal).abs() < 2) values.add(goal);
    var lo = values.reduce(math.min), hi = values.reduce(math.max);
    final pad = math.max(.6, (hi - lo) * .15);
    lo -= pad;
    hi += pad;

    const left = 34.0, bottom = 20.0, top = 8.0;
    final w = size.width - left - 4, h = size.height - bottom - top;
    double x(DateTime d) => left + w * (d.difference(start).inMinutes / span).clamp(0, 1);
    double y(double kg) => top + h * (1 - (kg - lo) / (hi - lo));

    // Grid: three lines, labelled in the user's unit.
    final grid = Paint()
      ..color = BloomColors.line
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final kg = lo + (hi - lo) * (.15 + .35 * i);
      final gy = y(kg);
      canvas.drawLine(Offset(left, gy), Offset(size.width, gy), grid);
      _text(canvas, units.show(kg).toStringAsFixed(0), Offset(0, gy - 8), left - 8);
    }
    // Date labels: start and end.
    String d(DateTime t) => '${_months[t.month - 1]} ${t.day}';
    _text(canvas, d(start), Offset(left, size.height - 15), 80, align: TextAlign.left);
    _text(canvas, d(end), Offset(size.width - 80, size.height - 15), 80, align: TextAlign.right);

    // Goal line.
    if (goal != null && goal < first.kg && goal >= lo) {
      final gy = y(goal);
      final p = Paint()
        ..color = BloomColors.mustard
        ..strokeWidth = 1.5;
      for (var gx = left; gx < size.width; gx += 6) {
        canvas.drawLine(Offset(gx, gy), Offset(math.min(gx + 2, size.width), gy), p);
      }
    }

    // Plan: dashed.
    final plan = Path()..moveTo(x(start), y(first.kg));
    for (var i = 1; i <= 24; i++) {
      final dt = start.add(Duration(minutes: (span * i / 24).round()));
      plan.lineTo(x(dt), y(log.plannedOn(dt)!));
    }
    final planPaint = Paint()
      ..color = BloomColors.skyDeep
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final m in plan.computeMetrics()) {
      for (var s = 0.0; s < m.length * t; s += 9) {
        canvas.drawPath(m.extractPath(s, math.min(s + 5, m.length * t)), planPaint);
      }
    }

    // The user's line, drawn in with t.
    final pts = [for (final e in log.entries) Offset(x(e.at), y(e.kg))];
    if (pts.length > 1) {
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1], b = pts[i];
        final mx = (a.dx + b.dx) / 2;
        line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
      }
      final metric = line.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * t),
        Paint()
          ..color = BloomColors.forest
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    // Dots appear as the line reaches them; the latest one is bigger.
    for (var i = 0; i < pts.length; i++) {
      final at = pts.length == 1 ? 0.0 : i / (pts.length - 1);
      final k = ((t - at * .9) / .1).clamp(0.0, 1.0);
      if (k == 0) continue;
      final last = i == pts.length - 1;
      canvas.drawCircle(pts[i], (last ? 7 : 4.5) * Curves.easeOutBack.transform(k), Paint()..color = BloomColors.surface);
      canvas.drawCircle(pts[i], (last ? 5 : 3) * Curves.easeOutBack.transform(k), Paint()..color = BloomColors.forest);
    }
  }

  void _text(Canvas canvas, String s, Offset at, double width, {TextAlign align = TextAlign.right}) {
    final p = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: align, fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700))
      ..pushStyle(ui.TextStyle(color: BloomColors.inkMuted, fontVariations: [const FontVariation('wght', 700)]))
      ..addText(s);
    final para = p.build()..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(para, at);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.t != t || old.log != log || old.units.pounds != units.pounds;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String shortDate(DateTime t) => '${_months[t.month - 1]} ${t.day}';
const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
