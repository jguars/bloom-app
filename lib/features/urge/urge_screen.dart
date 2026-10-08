import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/today.dart';
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

  // Just left of her cheek in craving-surf.jpg (1100x842), mapped through the scene's cover fit.
  static const _art = Size(1100, 842), _head = Offset(478, 400);
  double _k(double w, double h) => w / _art.width > h / _art.height ? w / _art.width : h / _art.height;
  double _headX(double w, double h) => (w - _art.width * _k(w, h)) / 2 + _head.dx * _k(w, h);
  double _headY(double w, double h) => (h - _art.height * _k(w, h)) / 2 + _head.dy * _k(w, h);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sceneH = (mq.size.height * .46).clamp(320.0, 420.0);
    return Scaffold(
      backgroundColor: BloomColors.surface,
      body: Stack(fit: StackFit.expand, children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          // Clover riding the craving out like a wave (painted). The sea bobs gently; on the
          // breathing task it swells with each breath.
          child: Scene(
            asset: 'assets/scenes/craving-surf.jpg',
            height: sceneH,
            fadeHeight: 80,
            motion: _stage == _Stage.doing && _task == UrgeTask.breathe ? SceneMotion.beat : SceneMotion.drift,
            motes: false,
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
        // Her line hangs beside her head, its tail tipping toward her (like the rooms' bubbles).
        Positioned(
          left: 16,
          right: mq.size.width - _headX(mq.size.width, sceneH) + 4,
          bottom: mq.size.height - _headY(mq.size.width, sceneH) + 4,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.bottomRight,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_line),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: BloomMotion.pop,
                builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: .6 + .4 * v, alignment: Alignment.bottomRight, child: child)),
                child: SpeechBubble(text: _line, tailRight: true, maxWidth: 200),
              ),
            ),
          ),
        ),
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
