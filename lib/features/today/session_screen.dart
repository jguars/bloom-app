import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/feel.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/exercises.dart';
import '../../data/today.dart';
import '../../ui/clover_rive.dart';
import '../../ui/ledge_button.dart';
import '../../ui/clover_scene.dart';
import '../../ui/scene.dart';
import '../../ui/speech_bubble.dart';
import 'celebration_screen.dart';
import 'flow.dart';
import 'ready_screen.dart';

/// 3-2-1, then the move: a live countdown, a progress bar, and Clover's cues
/// changing every quarter of the way.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.ex});
  final Exercise ex;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _elapsed = Duration.zero, _lastTick = Duration.zero;
  int _count = 3; // 3-2-1 before starting
  bool _paused = false, _finished = false;

  @override
  void initState() {
    super.initState();
    _countdown();
  }

  Future<void> _countdown() async {
    for (var i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _count = i);
      SfxPlayer.instance.play(Sfx.tick);
      Feel.selectionClick();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    if (!mounted) return;
    setState(() => _count = 0);
    SfxPlayer.instance.play(Sfx.go);
    Feel.mediumImpact();
    _ticker.start();
  }

  void _tick(Duration t) {
    final dt = t - _lastTick;
    _lastTick = t;
    if (_paused) return;
    setState(() => _elapsed += dt);
    if (_elapsed.inMilliseconds >= widget.ex.seconds * 1000) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _ticker.stop();
    SfxPlayer.instance.play(Sfx.done);
    Feel.heavyImpact();
    final reward = ref.read(todayProvider.notifier).finish();
    Navigator.of(context).pushReplacement(bloomRoute(CelebrationScreen(ex: widget.ex, reward: reward)));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sceneH = (mq.size.height * .55).clamp(380.0, 500.0);
    final total = widget.ex.seconds;
    final p = (_elapsed.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
    final left = (total - _elapsed.inSeconds).clamp(0, total);
    final cue = widget.ex.cues[(p * widget.ex.cues.length).floor().clamp(0, widget.ex.cues.length - 1)];
    final action = actionFor(widget.ex);
    String fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: BloomColors.surface,
      body: Stack(fit: StackFit.expand, children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          // Marching moves walk through the scrolling park; the rest stay in the still scene.
          child: action == CloverAction.march
              ? CloverSceneView(scene: CloverScene.march, height: sceneH, walking: _count == 0 && !_paused)
              : Scene(
                  asset: 'assets/scenes/march-empty.jpg',
                  height: sceneH,
                  motion: SceneMotion.still,
                  fadeHeight: 80,
                  groundAt: .8,
                  characterSize: .62,
                  characterX: .56,
                  character: LiveClover(action: _count > 0 || _paused ? CloverAction.rest : action, eyesOpen: _count > 0),
                ),
        ),
        Positioned(left: 12, top: mq.padding.top + 8, child: RoundButton(icon: Icons.close_rounded, label: 'End session', onTap: () => Navigator.of(context).pop())),
        if (_count == 0) Positioned(left: 110, top: sceneH * .28, child: SpeechBubble(text: _paused ? 'Catching our breath…' : cue)),
        Positioned.fill(
          top: sceneH - 24,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + mq.padding.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.ex.name.toUpperCase(), style: BloomText.label),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmt(left), style: BloomText.displayXl.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                const Spacer(),
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('of ${fmt(total)}', style: BloomText.caption)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(BloomSpace.rPill),
                child: SizedBox(
                  height: 14,
                  child: Stack(children: [
                    const Positioned.fill(child: ColoredBox(color: BloomColors.paperSunk)),
                    FractionallySizedBox(widthFactor: p, child: Container(decoration: BoxDecoration(color: BloomColors.forest, borderRadius: BorderRadius.circular(BloomSpace.rPill)))),
                  ]),
                ),
              ),
              const Spacer(),
              LedgeButton(
                label: _paused ? 'Resume' : 'Pause',
                variant: LedgeVariant.secondary,
                leading: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: BloomColors.ink),
                onPressed: _count == 0 ? () => setState(() => _paused = !_paused) : null,
              ),
              const SizedBox(height: 6),
              if (kDebugMode) Center(child: LedgeButton(label: 'Skip to the end (debug)', variant: LedgeVariant.ghost, expand: false, onPressed: _count == 0 ? _finish : null)),
            ]),
          ),
        ),
        if (_count > 0) Positioned.fill(child: _Countdown(count: _count)),
      ]),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: BloomColors.ink.withValues(alpha: .35),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: BloomMotion.pop,
            transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 1.8, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
            child: Container(
              key: ValueKey(count),
              width: 140,
              height: 140,
              decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x292E3826), blurRadius: 32, offset: Offset(0, 12))]),
              alignment: Alignment.center,
              child: Text('$count', style: BloomText.displayXl.copyWith(fontSize: 72, height: 1, color: BloomColors.forest)),
            ),
          ),
        ),
      );
}
