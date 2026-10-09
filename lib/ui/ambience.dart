import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// What drifts through a room: each scene gets its own small weather.
enum AmbienceKind {
  /// Porch: pollen rising in the sun.
  pollen,

  /// Indoors: dust motes turning slowly in the window light.
  dust,

  /// Balcony: lavender and blossom petals tumbling down.
  petals,

  /// The park: leaves blowing past (faster at a brisker [Ambience.speed]).
  leaves,

  /// Twinkling four-point sparkles, for eager and proud moments.
  sparkles,

  /// Night: fireflies wandering and glowing.
  fireflies,

  /// Celebration: paper confetti falling.
  confetti,
}

/// A layer of slow particles over a scene. Drawn on one ticker, a few dozen at a time, and absent
/// when the system asks for reduced motion.
class Ambience extends StatefulWidget {
  const Ambience({super.key, required this.kind, this.speed = 1, this.density = 1});
  final AmbienceKind kind;

  /// How fast everything drifts (the park's leaves follow the chosen pace).
  final double speed;

  /// How many particles, relative to the kind's usual count.
  final double density;

  @override
  State<Ambience> createState() => _AmbienceState();
}

class _Mote {
  _Mote(this.x, this.y, this.size, this.phase, this.drift, this.color, this.spin);
  double x, y; // 0..1 of the box
  final double size, phase, drift, spin;
  final Color color;
}

class _AmbienceState extends State<Ambience> with SingleTickerProviderStateMixin {
  final _rnd = math.Random(7);
  final _motes = <_Mote>[];
  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  Duration _last = Duration.zero;

  static const _palettes = {
    AmbienceKind.pollen: [Color(0xFFF6E8B8), Color(0xFFD6B23C), Color(0xFFFFFBF3)],
    AmbienceKind.dust: [Color(0xFFFFFBF3), Color(0xFFF6E8B8)],
    AmbienceKind.petals: [Color(0xFFB9A3D6), Color(0xFFF5DECF), Color(0xFFFFFBF3), Color(0xFFE8B4C8)],
    AmbienceKind.leaves: [Color(0xFFA9BC93), Color(0xFF5E7F4A), Color(0xFFD6B23C)],
    AmbienceKind.sparkles: [Color(0xFFD6B23C), Color(0xFFF6E8B8), Color(0xFFFFFBF3)],
    AmbienceKind.fireflies: [Color(0xFFF6E8B8), Color(0xFFFFF2B0)],
    AmbienceKind.confetti: [Color(0xFFD6B23C), Color(0xFF4A6838), Color(0xFFC9714B), Color(0xFFA9BC93), Color(0xFF36697F), Color(0xFFF5DECF)],
  };

  static const _counts = {
    AmbienceKind.pollen: 18,
    AmbienceKind.dust: 16,
    AmbienceKind.petals: 14,
    AmbienceKind.leaves: 12,
    AmbienceKind.sparkles: 10,
    AmbienceKind.fireflies: 12,
    AmbienceKind.confetti: 34,
  };

  @override
  void initState() {
    super.initState();
    _seed();
    _ticker.start();
  }

  @override
  void didUpdateWidget(Ambience old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind || old.density != widget.density) _seed();
  }

  void _seed() {
    _motes.clear();
    final colors = _palettes[widget.kind]!;
    final n = (_counts[widget.kind]! * widget.density).round();
    for (var i = 0; i < n; i++) {
      _motes.add(_Mote(
        _rnd.nextDouble(),
        _rnd.nextDouble(),
        .5 + _rnd.nextDouble(),
        _rnd.nextDouble() * math.pi * 2,
        .6 + _rnd.nextDouble() * .8,
        colors[_rnd.nextInt(colors.length)],
        (_rnd.nextDouble() - .5) * 4,
      ));
    }
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, .05);
    _last = now;
    final s = widget.speed;
    for (final m in _motes) {
      switch (widget.kind) {
        case AmbienceKind.pollen:
        case AmbienceKind.dust:
          m.y -= dt * .018 * m.drift * s;
          m.x += dt * .006 * math.sin(_time.value * .6 + m.phase) * s;
        case AmbienceKind.petals:
          m.y += dt * .05 * m.drift * s;
          m.x += dt * (.018 + .02 * math.sin(_time.value + m.phase)) * s;
        case AmbienceKind.leaves:
          m.x -= dt * .09 * m.drift * s;
          m.y += dt * .02 * math.sin(_time.value * 1.4 + m.phase) * s;
        case AmbienceKind.sparkles:
          m.y -= dt * .008 * m.drift;
        case AmbienceKind.fireflies:
          m.x += dt * .02 * math.cos(_time.value * .5 * m.drift + m.phase);
          m.y += dt * .016 * math.sin(_time.value * .7 * m.drift + m.phase);
        case AmbienceKind.confetti:
          m.y += dt * .11 * m.drift * s;
          m.x += dt * .02 * math.sin(_time.value * 2 + m.phase);
      }
      if (m.y < -.05) m.y += 1.1;
      if (m.y > 1.05) m.y -= 1.1;
      if (m.x < -.05) m.x += 1.1;
      if (m.x > 1.05) m.x -= 1.1;
    }
    _time.value += dt;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(child: CustomPaint(painter: _AmbiencePainter(widget.kind, _motes, _time), size: Size.infinite)),
    );
  }
}

class _AmbiencePainter extends CustomPainter {
  _AmbiencePainter(this.kind, this.motes, this.time) : super(repaint: time);
  final AmbienceKind kind;
  final List<_Mote> motes;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final paint = Paint();
    for (final m in motes) {
      final p = Offset(m.x * size.width, m.y * size.height);
      final tw = .5 + .5 * math.sin(t * 1.6 * m.drift + m.phase); // a slow twinkle
      switch (kind) {
        case AmbienceKind.pollen:
          paint.color = m.color.withValues(alpha: .35 + .45 * tw);
          canvas.drawCircle(p, 1.6 + 1.6 * m.size, paint);
        case AmbienceKind.dust:
          paint
            ..color = m.color.withValues(alpha: .18 + .4 * tw)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
          canvas.drawCircle(p, 1.4 + 2.2 * m.size, paint);
          paint.maskFilter = null;
        case AmbienceKind.petals:
        case AmbienceKind.leaves:
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(m.phase + t * m.spin * .4);
          final w = (kind == AmbienceKind.leaves ? 9.0 : 6.0) * m.size;
          paint.color = m.color.withValues(alpha: .85);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: w * .55 * (.6 + .4 * math.cos(t * 2 + m.phase).abs())), paint);
          canvas.restore();
        case AmbienceKind.sparkles:
          final r = (3 + 5 * m.size) * (.2 + .8 * tw);
          paint.color = m.color.withValues(alpha: .4 + .6 * tw);
          canvas.drawPath(_star(p, r), paint);
        case AmbienceKind.fireflies:
          paint
            ..color = m.color.withValues(alpha: .15 + .55 * tw)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawCircle(p, 5 + 4 * m.size, paint);
          paint
            ..maskFilter = null
            ..color = const Color(0xFFFFFBF3).withValues(alpha: .4 + .6 * tw);
          canvas.drawCircle(p, 1.6, paint);
        case AmbienceKind.confetti:
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(m.phase + t * m.spin);
          paint.color = m.color;
          final flip = math.cos(t * 3 * m.drift + m.phase);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 7 * m.size, height: 11 * m.size * flip.abs().clamp(.15, 1)), const Radius.circular(1.5)), paint);
          canvas.restore();
      }
    }
  }

  static Path _star(Offset c, double r) {
    final s = r * .28;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + s, c.dy - s, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + s, c.dy + s, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - s, c.dy + s, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - s, c.dy - s, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(_AmbiencePainter old) => old.kind != kind || old.motes != motes;
}
