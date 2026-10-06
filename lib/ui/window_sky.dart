import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/clock.dart';
import 'clover_scene.dart';

/// The sky in the bedroom's round window, painted over the room art: the same time of day as the
/// living room's window (see RoomLight): a clear blue day, a warm dusk, a pink dawn, and at night a
/// deep blue sky with the moon and twinkling stars. Paper clouds drift slowly left to right behind
/// the window's cross and the treeline (bedroom-window.png), which dim with the light.
class BedroomWindow extends ConsumerStatefulWidget {
  const BedroomWindow({super.key});

  /// The glass, in the bedroom art's units (CloverScene.profile), and where the cross-and-trees
  /// cut-out sits over it.
  static const center = Offset(961, 248.5), radius = 118.5;
  static const front = Rect.fromLTWH(840, 128, 242, 242);

  @override
  ConsumerState<BedroomWindow> createState() => _BedroomWindowState();
}

class _BedroomWindowState extends ConsumerState<BedroomWindow> with SingleTickerProviderStateMixin {
  // One full drift of the slowest cloud across the glass.
  late final _drift = AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();

  // (asset, width in art units, top within the glass, speed, phase)
  static const _clouds = [
    ('assets/scenes/sky-cloud-a.png', 150.0, 26.0, 1.0, .1),
    ('assets/scenes/sky-cloud-b.png', 96.0, 92.0, 1.45, .62),
    ('assets/scenes/sky-cloud-c.png', 64.0, 58.0, 1.9, .35),
  ];

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final h = now.hour + now.minute / 60;
    final light = SkyLight(h);
    final reduce = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, box) {
        const scene = CloverScene.profile;
        final size = box.biggest;
        final k = scene.scaleIn(size);
        final c = scene.toScreen(BedroomWindow.center, size);
        final r = BedroomWindow.radius * k;
        final glass = Rect.fromCircle(center: c, radius: r);
        final front = Rect.fromPoints(scene.toScreen(BedroomWindow.front.topLeft, size), scene.toScreen(BedroomWindow.front.bottomRight, size));
        return Stack(children: [
          Positioned.fromRect(
            rect: glass,
            child: ClipOval(
              child: AnimatedBuilder(
                animation: _drift,
                builder: (context, _) => Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: CustomPaint(painter: _SkyPainter(light, _drift.value))),
                  for (final (asset, w, top, speed, phase) in _clouds)
                    Positioned(
                      // Enters from the left, leaves on the right, then comes round again.
                      left: -w * k + (glass.width + w * k) * ((reduce ? phase : _drift.value * speed + phase) % 1),
                      top: top * k,
                      width: w * k,
                      child: ColorFiltered(colorFilter: ColorFilter.mode(light.cloudTint, BlendMode.modulate), child: Image.asset(asset, fit: BoxFit.fitWidth)),
                    ),
                ]),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: front,
            child: ColorFiltered(colorFilter: ColorFilter.mode(light.frontTint, BlendMode.modulate), child: Image.asset('assets/scenes/bedroom-window.png', fit: BoxFit.fill)),
          ),
        ]);
      }),
    );
  }
}

double _ramp(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);

/// How much night, dusk and dawn there is at [hour] (the same curves as RoomLight), and the colours
/// they make in the window.
class SkyLight {
  SkyLight(double hour)
      : night = hour >= 12 ? _ramp(hour, 18.5, 21) : 1 - _ramp(hour, 5, 7),
        dusk = math.max(0.0, 1 - (hour - 19).abs() / 2.2),
        dawn = math.max(0.0, 1 - (hour - 6.5).abs() / 1.5);
  final double night, dusk, dawn;

  static const _dayTop = Color(0xFFB1D5E5), _dayBottom = Color(0xFFC6E5F0);
  static const _nightTop = Color(0xFF16233F), _nightBottom = Color(0xFF2B3F66);

  Color get top => Color.lerp(Color.lerp(_dayTop, const Color(0xFFE9B48C), dusk * .55 + dawn * .25)!, _nightTop, night)!;
  Color get bottom => Color.lerp(Color.lerp(_dayBottom, const Color(0xFFF7C9B6), dusk * .6 + dawn * .55)!, _nightBottom, night)!;
  Color get cloudTint => Color.lerp(Color.lerp(Colors.white, const Color(0xFFFFD9C2), math.max(dusk, dawn) * .7)!, const Color(0xFF7D86A6), night)!;
  Color get frontTint => Color.lerp(Colors.white, const Color(0xFF8A93B0), night * .8)!;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.light, this.t);
  final SkyLight light;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light.top, light.bottom]).createShader(r));
    final night = light.night;
    if (night < .01) return;
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * .55);
      final tw = .5 + .5 * math.sin(2 * math.pi * (t * 12 + rnd.nextDouble()));
      canvas.drawCircle(p, size.width * (.006 + rnd.nextDouble() * .006), Paint()..color = const Color(0xFFFFF6D8).withValues(alpha: night * (.35 + .65 * tw)));
    }
    // A crescent moon, where the painting had it.
    final m = Offset(size.width * .7, size.height * .3), mr = size.width * .1;
    canvas.drawCircle(m, mr * 2, Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: .1 * night));
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: m, radius: mr)),
      Path()..addOval(Rect.fromCircle(center: m + Offset(mr * .45, -mr * .3), radius: mr * .9)),
    );
    canvas.drawPath(moon, Paint()..color = const Color(0xFFF0C95A).withValues(alpha: night));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t || old.light.night != light.night || old.light.dusk != light.dusk || old.light.dawn != light.dawn;
}
