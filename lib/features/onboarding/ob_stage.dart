import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../ui/ambience.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/scene.dart';

/// What the onboarding stage shows on a page: one of Clover's live rooms (with what she's doing in
/// it), or a still painting, plus the room's drifting particles.
class StageSpec {
  const StageSpec.room(CloverScene this.scene, {this.action, this.walking = false, this.eyesOpen = false, this.cheering = false, required this.ambience, this.speed = 1, this.overlay, this.framing})
      : asset = null,
        alignment = Alignment.center;
  const StageSpec.still(String this.asset, {required this.ambience, this.alignment = Alignment.center})
      : scene = null,
        action = null,
        walking = false,
        eyesOpen = false,
        cheering = false,
        speed = 1,
        overlay = null,
        framing = null;

  final CloverScene? scene;
  final String? asset;
  final Alignment alignment;
  final CloverAction? action;
  final bool walking, eyesOpen, cheering;
  final AmbienceKind ambience;

  /// The particles' drift speed (the park's leaves follow the chosen pace).
  final double speed;

  /// Painted over the room, under its fade (the bedroom's live sky).
  final Widget? overlay;

  /// How a room is framed on the stage, where it differs from the room tab's.
  final Alignment? framing;

  /// Pages that share a room keep one live scene: she carries on rather than starting over.
  Object get room => scene ?? asset!;
}

/// The top of every onboarding page: Clover's room, kept alive from page to page. A new room comes in
/// with a zoom-through (the old one pushes past the camera as the new one settles) and a soft bloom of
/// light; the same room just carries on, so whatever she was doing flows into the next question.
class ObStage extends StatefulWidget {
  const ObStage({super.key, required this.spec, required this.height, this.line, this.lineAt = const Alignment(-.6, -.45), this.onTapClover, this.extra});
  final StageSpec spec;
  final double height;

  /// What she says, in a bubble that pops whenever it changes.
  final String? line;
  final Alignment lineAt;
  final void Function(Offset global)? onTapClover;

  /// Anything else on the stage (a sample notification).
  final Widget? extra;

  @override
  State<ObStage> createState() => _ObStageState();
}

class _ObStageState extends State<ObStage> with SingleTickerProviderStateMixin {
  late final _bloom = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(ObStage old) {
    super.didUpdateWidget(old);
    if (old.spec.room != widget.spec.room) _bloom.forward(from: 0);
  }

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  Widget _room(StageSpec s) {
    final art = s.scene != null
        ? CloverSceneView(
            scene: s.scene!,
            height: widget.height,
            action: s.action,
            walking: s.walking,
            eyesOpen: s.eyesOpen,
            cheering: s.cheering,
            overlay: s.overlay,
            fadeHeight: 0,
            alignment: s.framing,
          )
        : Scene(asset: s.asset!, height: widget.height, fadeHeight: 0, alignment: s.alignment, motes: false);
    return Stack(fit: StackFit.expand, children: [
      art,
      Ambience(kind: s.ambience, speed: s.speed),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.onTapClover == null ? null : (d) => widget.onTapClover!(d.globalPosition),
        child: Stack(fit: StackFit.expand, clipBehavior: Clip.hardEdge, children: [
          ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 820),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
              transitionBuilder: (child, a) {
                final incoming = child.key == ValueKey(s.room);
                return AnimatedBuilder(
                  animation: a,
                  child: child,
                  builder: (context, child) {
                    final t = a.value;
                    // Leaving: pushes past the camera; arriving: settles in from slightly close.
                    final scale = incoming ? 1 + (1 - t) * .07 : 1 + (1 - t) * .16;
                    return Opacity(opacity: t.clamp(0, 1), child: Transform.scale(scale: scale, child: child));
                  },
                );
              },
              child: KeyedSubtree(key: ValueKey(s.room), child: _room(s)),
            ),
          ),
          // The bloom of light between rooms.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _bloom,
              builder: (context, _) {
                final v = math.sin(_bloom.value * math.pi);
                if (v <= 0) return const SizedBox.shrink();
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: .9,
                      colors: [BloomColors.surface.withValues(alpha: .55 * v), BloomColors.mustardSoft.withValues(alpha: .25 * v), Colors.transparent],
                      stops: const [0, .55, 1],
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.extra != null) widget.extra!,
          if (widget.line != null)
            AnimatedAlign(
              duration: const Duration(milliseconds: 600),
              curve: BloomMotion.spring,
              alignment: widget.lineAt,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: ObBubble(line: widget.line!)),
            ),
        ]),
      ),
    );
  }
}

/// Clover's speech bubble on the stage: bobs gently, and pops with a little overshoot each time she
/// says something new.
class ObBubble extends StatefulWidget {
  const ObBubble({super.key, required this.line});
  final String line;

  @override
  State<ObBubble> createState() => _ObBubbleState();
}

class _ObBubbleState extends State<ObBubble> with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _bob,
        builder: (context, child) => Transform.translate(offset: Offset(0, 3 * math.sin(_bob.value * 2 * math.pi)), child: child),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: BloomMotion.pop,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .7, end: 1.0).animate(a), alignment: Alignment.bottomLeft, child: c)),
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
          child: ConstrainedBox(
            key: ValueKey(widget.line),
            constraints: const BoxConstraints(maxWidth: 236),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: BloomColors.surface,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomRight: Radius.circular(20), bottomLeft: Radius.circular(6)),
                boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 2)), BoxShadow(color: Color(0x24403A1E), blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: Text(widget.line, style: BloomText.bubble.copyWith(fontSize: 16, height: 22 / 16)),
            ),
          ),
        ),
      );
}
