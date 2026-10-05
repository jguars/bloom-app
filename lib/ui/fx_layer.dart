import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/theme.dart';
import 'paw.dart';

/// One app-wide overlay for joy: confetti bursts and paw chips that fly to a
/// target. It sits above every route, so a celebration can begin on one screen
/// and land on the next.
class FxLayer extends StatefulWidget {
  const FxLayer({super.key, required this.child});
  final Widget child;

  static final _key = GlobalKey<_FxLayerState>();

  /// Wrap the app with this (see [FxLayer.wrap]).
  static Widget wrap(Widget child) => FxLayer(key: _key, child: child);

  /// Confetti from [origin] (global coordinates).
  static void burst(Offset origin, {int count = 60, double power = 1}) => _key.currentState?._burst(origin, count, power);

  /// A "+[text]" paw chip flying from [from] to [to].
  static void fly(Offset from, Offset to, String text, {Duration delay = Duration.zero}) =>
      _key.currentState?._fly(from, to, text, delay);

  @override
  State<FxLayer> createState() => _FxLayerState();
}

class _Particle {
  _Particle(this.pos, this.vel, this.color, this.w, this.h, this.spin, this.life, this.round);
  Offset pos;
  Offset vel;
  final Color color;
  final double w, h, spin, life;
  final bool round;
  double age = 0, angle = 0;
}

class _Flyer {
  _Flyer(this.from, this.to, this.text, this.start);
  final Offset from, to;
  final String text;
  final Duration start;
}

class _FxLayerState extends State<FxLayer> with SingleTickerProviderStateMixin {
  final _parts = <_Particle>[];
  final _flyers = <_Flyer>[];
  final _rnd = math.Random();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero, _now = Duration.zero;

  void _burst(Offset o, int n, double power) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + (_rnd.nextDouble() - .5) * math.pi * 1.6;
      final v = (380 + _rnd.nextDouble() * 520) * power;
      final round = _rnd.nextDouble() < .25;
      _parts.add(_Particle(o, Offset(math.cos(a) * v, math.sin(a) * v), BloomColors.confetti[i % BloomColors.confetti.length],
          round ? 8 : 6 + _rnd.nextDouble() * 6, round ? 8 : 10 + _rnd.nextDouble() * 6, (_rnd.nextDouble() - .5) * 14, 1.6 + _rnd.nextDouble() * .9, round));
    }
    _start();
  }

  void _fly(Offset from, Offset to, String text, Duration delay) {
    _flyers.add(_Flyer(from, to, text, _now + delay));
    _start();
  }

  void _start() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _now = Duration.zero;
      _ticker.start();
    }
    setState(() {});
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _now = elapsed;
    for (final p in _parts) {
      p.age += dt;
      p.vel = Offset(p.vel.dx * (1 - 1.6 * dt), p.vel.dy * (1 - 1.6 * dt) + 900 * dt);
      p.pos += p.vel * dt;
      p.angle += p.spin * dt;
    }
    _parts.removeWhere((p) => p.age > p.life);
    _flyers.removeWhere((f) => elapsed - f.start > const Duration(milliseconds: 950));
    if (_parts.isEmpty && _flyers.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_parts.isNotEmpty) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_parts)))),
      for (final f in _flyers)
        if (_now >= f.start) _flyerWidget(f),
    ]);
  }

  Widget _flyerWidget(_Flyer f) {
    final t = ((_now - f.start).inMilliseconds / 950).clamp(0.0, 1.0);
    final e = Curves.easeInOutCubic.transform(t);
    // Arc: rises, then swoops into the target.
    final mid = Offset((f.from.dx + f.to.dx) / 2, math.min(f.from.dy, f.to.dy) - 80);
    final a = Offset.lerp(f.from, mid, e)!;
    final b = Offset.lerp(mid, f.to, e)!;
    final pos = Offset.lerp(a, b, e)!;
    final scale = t < .2 ? .6 + 2 * t : 1.0 - .5 * ((t - .2) / .8);
    final opacity = t > .85 ? (1 - t) / .15 : 1.0;
    return Positioned(
      left: pos.dx - 36,
      top: pos.dy - 17,
      child: IgnorePointer(child: Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: EarnChip(text: f.text)))),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.parts);
  final List<_Particle> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in parts) {
      final fade = p.age > p.life - .4 ? ((p.life - p.age) / .4).clamp(0.0, 1.0) : 1.0;
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.angle);
      // A flutter: width shrinks and grows as it tumbles.
      final w = p.round ? p.w : p.w * (0.35 + 0.65 * math.cos(p.angle * 2).abs());
      final r = Rect.fromCenter(center: Offset.zero, width: w, height: p.h);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(p.round ? p.w : 2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
