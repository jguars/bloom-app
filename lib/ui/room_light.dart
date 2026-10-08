import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Time-of-day light for the living room, painted over the room art: a pink
/// dawn, a warm dusk in the window, and at night a dim room with stars, a
/// moon and the floor lamp glowing. Positions are in the art's own pixels
/// (1066×1100) and mapped through the same BoxFit.cover as the image.
class RoomLight extends StatefulWidget {
  const RoomLight({super.key, required this.time});
  final DateTime time;

  @override
  State<RoomLight> createState() => _RoomLightState();
}

class _RoomLightState extends State<RoomLight> with SingleTickerProviderStateMixin {
  late final _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  /// The window's glass, without the sofa and the TV in front of it (living-glass.png, same size
  /// as the art): the window's tint, stars and moon are clipped to it.
  static Future<ui.Image>? _glass;
  ui.Image? _mask;

  @override
  void initState() {
    super.initState();
    _glass ??= rootBundle.load('assets/scenes/living-glass.png').then((d) => decodeImageFromList(d.buffer.asUint8List()));
    _glass!
        .then((m) {
          if (mounted) setState(() => _mask = m);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.time.hour + widget.time.minute / 60;
    // The stars only twinkle at night; by day nothing here moves, so don't redraw every frame.
    final dark = h >= 18.5 || h < 7;
    if (dark && !_twinkle.isAnimating) {
      _twinkle.repeat();
    } else if (!dark && _twinkle.isAnimating) {
      _twinkle.stop();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _twinkle,
        builder: (context, _) => CustomPaint(painter: _LightPainter(h, _twinkle.value, _mask), size: Size.infinite),
      ),
    );
  }
}

double _ramp(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);

class _LightPainter extends CustomPainter {
  _LightPainter(this.hour, this.t, this.mask);
  final double hour, t;
  final ui.Image? mask;

  static const _img = Size(1066, 1100);
  static const _window = Rect.fromLTRB(103, 62, 943, 600);
  static const _sky = Rect.fromLTRB(103, 62, 907, 360);
  static const _lamp = Offset(990, 420);
  static const _moon = Offset(600, 190);

  @override
  void paint(Canvas canvas, Size size) {
    // Night 0..1 (full 21:00-05:00), dusk peaks at 19:00, dawn at 06:30.
    final night = hour >= 12 ? _ramp(hour, 18.5, 21) : 1 - _ramp(hour, 5, 7);
    final dusk = math.max(0.0, 1 - (hour - 19).abs() / 2.2);
    final dawn = math.max(0.0, 1 - (hour - 6.5).abs() / 1.5);
    if (night < .01 && dusk < .01 && dawn < .01) return;

    final scale = math.max(size.width / _img.width, size.height / _img.height);
    final dx = (size.width - _img.width * scale) / 2, dy = (size.height - _img.height * scale) / 2;
    Offset p(Offset o) => Offset(dx + o.dx * scale, dy + o.dy * scale);
    Rect r(Rect o) => Rect.fromPoints(p(o.topLeft), p(o.bottomRight));
    final full = Offset.zero & size;

    // Draws [paint] clipped to the window's glass, so the sofa and the TV in front of it stay lit.
    void inGlass(void Function() paint) {
      final m = mask;
      if (m == null) {
        canvas.save();
        canvas.clipRect(r(_window));
        paint();
        canvas.restore();
        return;
      }
      canvas.saveLayer(full, Paint());
      paint();
      canvas.drawImageRect(
        m,
        Rect.fromLTWH(0, 0, m.width.toDouble(), m.height.toDouble()),
        Rect.fromLTWH(dx, dy, m.width * scale, m.height * scale),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }

    // Warm dusk / pink dawn in the window.
    if (dusk > 0 || dawn > 0) {
      final w = r(_window);
      inGlass(
        () => canvas.drawRect(
          w,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(const Color(0x00F2A65A), const Color(0x99F2A65A), dusk)!.withValues(alpha: .55 * dusk + .35 * dawn),
                const Color(0xFFF7C9B6).withValues(alpha: .25 * dawn + .15 * dusk),
              ],
            ).createShader(w),
        ),
      );
      canvas.drawRect(full, Paint()..color = const Color(0xFFF2A65A).withValues(alpha: .08 * dusk));
    }

    if (night < .01) return;
    // The room dims, the window goes deep blue.
    canvas.drawRect(full, Paint()..color = const Color(0xFF1C2A44).withValues(alpha: .42 * night));
    inGlass(() {
      final w = r(_window);
      canvas.drawRect(
        w,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF16233F).withValues(alpha: .85 * night),
              const Color(0xFF2B3F66).withValues(alpha: .55 * night),
            ],
          ).createShader(w),
      );
      // Stars twinkle in the sky part of the window.
      final sky = r(_sky);
      final rnd = math.Random(3);
      for (var i = 0; i < 26; i++) {
        final sx = sky.left + rnd.nextDouble() * sky.width, sy = sky.top + rnd.nextDouble() * sky.height * .8;
        final tw = .5 + .5 * math.sin(2 * math.pi * (t + rnd.nextDouble()));
        canvas.drawCircle(Offset(sx, sy), (1 + rnd.nextDouble() * 1.4) * (scale * 2.2), Paint()..color = const Color(0xFFFFF6D8).withValues(alpha: night * (.35 + .65 * tw)));
      }
      // The moon with a soft halo.
      final m = p(_moon);
      canvas.drawCircle(m, 70 * scale, Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: .12 * night));
      canvas.drawCircle(m, 34 * scale, Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: .95 * night));
      canvas.drawCircle(m + Offset(12 * scale, -8 * scale), 30 * scale, Paint()..color = const Color(0xFF16233F).withValues(alpha: .9 * night));
    });
    // The floor lamp is on.
    final l = p(_lamp);
    canvas.drawCircle(
      l,
      380 * scale,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD27A).withValues(alpha: .38 * night),
            const Color(0x00FFD27A),
          ],
        ).createShader(Rect.fromCircle(center: l, radius: 380 * scale)),
    );
  }

  @override
  bool shouldRepaint(_LightPainter old) => old.hour != hour || old.t != t || old.mask != mask;
}
