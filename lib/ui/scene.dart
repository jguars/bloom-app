import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

enum SceneMotion { drift, beat, hop, still }

/// A room illustration filling the top of a screen. It drifts slowly (a 16 s
/// push-in) with a few motes of light floating up, so a static picture still
/// feels alive. [fadeHeight] blends its bottom edge into the panel below.
class Scene extends StatefulWidget {
  const Scene({
    super.key,
    required this.asset,
    required this.height,
    this.motion = SceneMotion.drift,
    this.fadeHeight = 96,
    this.alignment = Alignment.center,
    this.motes = true,
    this.character,
    this.groundAt = .82,
    this.characterSize = .6,
    this.characterX = .5,
    this.overlay,
  });

  final String asset;
  final double height;
  final SceneMotion motion;
  final double fadeHeight;
  final Alignment alignment;
  final bool motes;

  /// A live character (the Rive Clover) standing in the room. It moves with
  /// the scene's drift so she stays planted on the floor.
  final Widget? character;

  /// Where her feet touch the floor, as a share of the scene height.
  final double groundAt;

  /// Her box height as a share of the scene height, and her centre across.
  final double characterSize, characterX;

  /// Painted over the art (under the character), moving with it.
  final Widget? overlay;

  @override
  State<Scene> createState() => _SceneState();
}

class _SceneState extends State<Scene> with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat(reverse: true);
  late final AnimationController _beat = AnimationController(vsync: this, duration: Duration(milliseconds: widget.motion == SceneMotion.hop ? 1600 : 640))..repeat();
  late final AnimationController _motes = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    _drift.dispose();
    _beat.dispose();
    _motes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          AnimatedBuilder(
            animation: Listenable.merge([_drift, _beat]),
            builder: (context, child) {
              if (reduce || widget.motion == SceneMotion.still) return child!;
              final d = Curves.easeInOut.transform(_drift.value);
              var scale = 1 + 0.07 * d;
              var dy = -4 * d;
              final b = math.sin(_beat.value * 2 * math.pi);
              if (widget.motion == SceneMotion.beat) {
                scale = 1.01 + 0.012 * (0.5 + 0.5 * b);
                dy = -3 * (0.5 + 0.5 * b);
              } else if (widget.motion == SceneMotion.hop) {
                dy += -6 * math.max(0, b);
              }
              return Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(scale: scale, alignment: const Alignment(0, 0.25), child: child),
              );
            },
            child: widget.character == null
                ? Stack(fit: StackFit.expand, children: [
                    Image.asset(widget.asset, fit: BoxFit.cover, alignment: widget.alignment, gaplessPlayback: true),
                    ?widget.overlay,
                  ])
                : LayoutBuilder(builder: (context, box) {
                    // The Rive artboard is 600×700 with her feet at y = 620.
                    final h = box.maxHeight * widget.characterSize;
                    final w = h * 600 / 700;
                    return Stack(fit: StackFit.expand, children: [
                      Image.asset(widget.asset, fit: BoxFit.cover, alignment: widget.alignment, gaplessPlayback: true),
                      ?widget.overlay,
                      Positioned(
                        left: box.maxWidth * widget.characterX - w / 2,
                        top: box.maxHeight * widget.groundAt - h * 620 / 700,
                        width: w,
                        height: h,
                        child: widget.character!,
                      ),
                    ]);
                  }),
          ),
          if (widget.motes && !reduce)
            IgnorePointer(child: AnimatedBuilder(animation: _motes, builder: (context, _) => CustomPaint(painter: _MotesPainter(_motes.value)))),
          if (widget.fadeHeight > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: widget.fadeHeight,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00FFFBF3), Color(0x8CFFFBF3), BloomColors.surface],
                      stops: [0, .45, 1],
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MotesPainter extends CustomPainter {
  _MotesPainter(this.t);
  final double t;
  static const _seeds = [
    (0.10, 0.80, 0.0), (0.28, 0.70, 0.17), (0.46, 0.85, 0.36), (0.64, 0.74, 0.55),
    (0.82, 0.82, 0.72), (0.18, 0.55, 0.86), (0.74, 0.50, 0.30), (0.56, 0.60, 0.64),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final (x, y, off) in _seeds) {
      final k = (t + off) % 1.0;
      final a = k < .2 ? k / .2 : 1 - (k - .2) / .8;
      p.color = const Color(0xFFFFFBF3).withValues(alpha: 0.85 * a);
      canvas.drawCircle(Offset(size.width * x + 18 * k, size.height * y - 120 * k), 3, p);
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) => old.t != t;
}
