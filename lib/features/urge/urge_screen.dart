import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/today.dart';
import '../../ui/clover_rive.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/scene.dart';
import '../../ui/speech_bubble.dart';

/// Something small to do with Clover until a craving passes.
enum UrgeTask {
  water('Drink a glass of water', 'Slow sips. Cravings often start as thirst.', Icons.water_drop_rounded, 45),
  breathe('Breathe with me', 'Four slow breaths, in and out together.', Icons.air_rounded, 40),
  walk('A short walk', 'Three minutes, anywhere. I’ll march along.', Icons.directions_walk_rounded, 180),
  room('Change rooms', 'New place, new thoughts. Look out a window.', Icons.door_front_door_outlined, 60);

  const UrgeTask(this.title, this.caption, this.icon, this.seconds);
  final String title, caption;
  final IconData icon;
  final int seconds;
}

enum _Stage { pick, doing, ask, done }

/// "Craving something?" Clover suggests a tiny task, does it with you, then
/// asks whether it passed. Never a lecture; riding it out earns paws.
class UrgeScreen extends ConsumerStatefulWidget {
  const UrgeScreen({super.key});

  @override
  ConsumerState<UrgeScreen> createState() => _UrgeScreenState();
}

class _UrgeScreenState extends ConsumerState<UrgeScreen> with SingleTickerProviderStateMixin {
  var _stage = _Stage.pick;
  UrgeTask? _task;
  late final AnimationController _clock = AnimationController(vsync: this);
  Timer? _breathTimer;
  bool _inhale = true;
  bool _passed = false;
  final _yesKey = GlobalKey();

  @override
  void dispose() {
    _clock.dispose();
    _breathTimer?.cancel();
    super.dispose();
  }

  void _start(UrgeTask t) {
    Feel.mediumImpact();
    setState(() {
      _task = t;
      _stage = _Stage.doing;
    });
    _clock.duration = Duration(seconds: t.seconds);
    _clock.forward(from: 0).whenComplete(() {
      if (mounted && _stage == _Stage.doing) _finishTask();
    });
    if (t == UrgeTask.water) SfxPlayer.instance.play(Sfx.drop);
    if (t == UrgeTask.walk || t == UrgeTask.room) SfxPlayer.instance.play(Sfx.go);
    if (t == UrgeTask.breathe) {
      _inhale = true;
      SfxPlayer.instance.play(Sfx.breatheIn);
      _breathTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        setState(() => _inhale = !_inhale);
        SfxPlayer.instance.play(_inhale ? Sfx.breatheIn : Sfx.breatheOut);
        Feel.selectionClick();
      });
    }
  }

  void _finishTask() {
    _breathTimer?.cancel();
    _clock.stop();
    SfxPlayer.instance.play(Sfx.chime);
    Feel.mediumImpact();
    setState(() => _stage = _Stage.ask);
  }

  void _answer(bool passed) {
    final pawsDue = ref.read(journalProvider.notifier).logUrge(passed: passed);
    setState(() {
      _passed = passed;
      _stage = passed ? _Stage.done : _Stage.pick;
    });
    if (!passed) {
      SfxPlayer.instance.play(Sfx.pop);
      return;
    }
    SfxPlayer.instance.play(Sfx.cheer);
    Feel.heavyImpact();
    final box = _yesKey.currentContext?.findRenderObject() as RenderBox?;
    final size = MediaQuery.of(context).size;
    final c = box?.localToGlobal(box.size.center(Offset.zero)) ?? Offset(size.width / 2, size.height * .6);
    FxLayer.burst(c, count: 50, power: .9);
    if (pawsDue) {
      FxLayer.fly(c, Offset(size.width - 60, MediaQuery.of(context).padding.top + 30), '+$kUrgePaws');
      Future.delayed(const Duration(milliseconds: 900), () => ref.read(todayProvider.notifier).addPaws(kUrgePaws));
    }
  }

  String get _line => switch (_stage) {
        _Stage.pick => _passed == false && _task != null ? 'Still there? Let’s try another one.' : 'Cravings pass like waves. Let’s ride this one out.',
        _Stage.doing => switch (_task!) {
            UrgeTask.water => 'Sip, sip… I’m having one too.',
            UrgeTask.breathe => _inhale ? 'Breathe in…' : 'And slowly out…',
            UrgeTask.walk => 'Left, right, left, right!',
            UrgeTask.room => 'Ooh, a change of scenery!',
          },
        _Stage.ask => 'How is it now?',
        _Stage.done => 'You did that! Proud of you.',
      };

  CloverAction get _action => switch (_stage) {
        _Stage.doing => switch (_task!) {
            UrgeTask.walk => CloverAction.march,
            UrgeTask.room => CloverAction.hop,
            UrgeTask.breathe => _inhale ? CloverAction.reach : CloverAction.rest,
            UrgeTask.water => CloverAction.rest,
          },
        _Stage.done => CloverAction.cheer,
        _ => CloverAction.rest,
      };

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sceneH = (mq.size.height * .46).clamp(320.0, 420.0);
    final walk = _stage == _Stage.doing && _task == UrgeTask.walk;
    return Scaffold(
      backgroundColor: BloomColors.surface,
      body: Stack(fit: StackFit.expand, children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedSwitcher(
            duration: BloomMotion.slow,
            child: Scene(
              key: ValueKey(walk),
              asset: walk ? 'assets/scenes/march-empty.jpg' : 'assets/scenes/ready-empty.jpg',
              height: sceneH,
              fadeHeight: 80,
              groundAt: walk ? .8 : .86,
              characterSize: .62,
              character: Stack(fit: StackFit.expand, children: [
                if (_stage == _Stage.doing && _task == UrgeTask.breathe) _BreathRing(inhale: _inhale),
                LiveClover(action: _action),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: mq.padding.top + 8,
          child: Semantics(
            button: true,
            label: 'Close',
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1F2E3826), blurRadius: 12, offset: Offset(0, 4))]),
                child: const Icon(Icons.close_rounded, color: BloomColors.ink),
              ),
            ),
          ),
        ),
        Positioned(left: 70, right: 16, top: mq.padding.top + 64, child: Align(alignment: Alignment.centerRight, child: SpeechBubble(text: _line, tailRight: true))),
        Positioned.fill(
          top: sceneH - 20,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + mq.padding.bottom),
            child: AnimatedSwitcher(
              duration: BloomMotion.base,
              switchInCurve: BloomMotion.enter,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a), child: c)),
              child: KeyedSubtree(key: ValueKey(_stage), child: _body()),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _body() => switch (_stage) {
        _Stage.pick => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Craving something?', style: BloomText.display),
            const SizedBox(height: 4),
            Text('Pick one small thing. Most cravings fade in a few minutes.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: UrgeTask.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => RiseIn(delay: BloomMotion.stagger * (i + 1), child: _TaskTile(task: UrgeTask.values[i], onTap: () => _start(UrgeTask.values[i]))),
              ),
            ),
          ]),
        _Stage.doing => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_task!.title, style: BloomText.title),
            Text(_task!.caption, style: BloomText.bodyMuted.copyWith(fontSize: 15)),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                final left = (_task!.seconds * (1 - _clock.value)).ceil();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}', style: BloomText.displayXl.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: _clock.value, minHeight: 10, color: BloomColors.forest, backgroundColor: BloomColors.paperSunk),
                  ),
                ]);
              },
            ),
            const Spacer(),
            LedgeButton(label: 'Done', onPressed: _finishTask),
          ]),
        _Stage.ask => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Did the craving pass?', style: BloomText.display),
            const SizedBox(height: 4),
            Text('Either answer is fine. You noticed it, and that matters.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
            const Spacer(),
            KeyedSubtree(key: _yesKey, child: LedgeButton(label: 'It passed', glow: true, onPressed: () => _answer(true))),
            const SizedBox(height: 10),
            LedgeButton(label: 'Still there', variant: LedgeVariant.secondary, onPressed: () => _answer(false)),
          ]),
        _Stage.done => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PopIn(child: Text('Rode it out!', style: BloomText.display, textAlign: TextAlign.center)),
            const SizedBox(height: 6),
            Text('That’s a real win. Clover’s doing a happy dance.', style: BloomText.bodyMuted, textAlign: TextAlign.center),
            const Spacer(),
            LedgeButton(label: 'Back to the house', onPressed: () => Navigator.of(context).pop()),
          ]),
      };
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});
  final UrgeTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: task.title,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BloomColors.surface,
              borderRadius: BorderRadius.circular(BloomSpace.rMd),
              border: Border.all(color: BloomColors.line, width: 2),
              boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 3))],
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
                child: Icon(task.icon, color: BloomColors.forest),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(task.title, style: BloomText.headline.copyWith(fontSize: 16)),
                  Text(task.caption, style: BloomText.caption),
                ]),
              ),
              Text(task.seconds >= 60 ? '${task.seconds ~/ 60} min' : '${task.seconds} s', style: BloomText.caption.copyWith(color: BloomColors.ink)),
            ]),
          ),
        ),
      );
}

/// A soft ring behind Clover that swells on the in-breath.
class _BreathRing extends StatelessWidget {
  const _BreathRing({required this.inhale});
  final bool inhale;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: inhale ? 1 : 0),
        duration: const Duration(seconds: 5),
        curve: Curves.easeInOut,
        builder: (context, v, _) => CustomPaint(painter: _RingPainter(v)),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * .55);
    final r = size.width * (.32 + .22 * v);
    canvas.drawCircle(c, r, Paint()..color = BloomColors.sky.withValues(alpha: .55));
    canvas.drawCircle(c, r, Paint()
      ..color = BloomColors.skyDeep.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + v * .6;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r + 10), 3, Paint()..color = BloomColors.skyDeep.withValues(alpha: .3 * v));
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v;
}
