import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/exercises.dart';
import '../../data/today.dart';
import '../../ui/day_ring.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/scene.dart';
import '../../ui/speech_bubble.dart';
import 'flow.dart';
import 'ready_screen.dart';

const _lines = [
  'Mm… sofa’s warm. Unless you’re coming?',
  'That was fun. Again later?',
  'One more and the ring’s full!',
  'Three! I’m so proud of us.',
];

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _chipKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(todayProvider);
    ref.listen(pendingRewardProvider, (_, r) {
      if (r != null) _playReward(r);
    });
    final mq = MediaQuery.of(context);
    final sceneH = (mq.size.height * .47).clamp(340.0, 470.0);
    final now = DateTime.now();
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return ColoredBox(
      color: BloomColors.surface,
      child: Stack(fit: StackFit.expand, children: [
        Positioned(left: 0, right: 0, top: 0, child: Scene(asset: s.goalMet ? 'assets/scenes/living-flex.jpg' : 'assets/scenes/living.jpg', height: sceneH)),
        Positioned(
          left: 16,
          right: 16,
          top: mq.padding.top + 12,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _Pill('${wd[now.weekday - 1]}, ${mo[now.month - 1]} ${now.day}'),
            PawChip(key: _chipKey, paws: s.paws),
          ]),
        ),
        Positioned(left: 140, right: 16, top: sceneH * .33, child: Align(alignment: Alignment.centerLeft, child: SpeechBubble(text: _lines[s.done.clamp(0, 3)]))),
        Positioned.fill(
          top: sceneH - 40,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 96 + mq.padding.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TODAY', style: BloomText.label),
                    Text('Move with Clover', style: BloomText.title),
                  ]),
                ),
                DayRing(done: s.done),
              ]),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 480),
                switchInCurve: BloomMotion.spring,
                switchOutCurve: BloomMotion.leave,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(.25, 0), end: Offset.zero).animate(a),
                    child: RotationTransition(turns: Tween(begin: .012, end: 0.0).animate(a), child: child),
                  ),
                ),
                child: s.goalMet
                    ? _DoneCard(key: const ValueKey('done'), onMore: () => _open(s.current))
                    : _PickCard(
                        key: ValueKey(s.current.id),
                        ex: s.current,
                        onGo: () => _open(s.current),
                        onSwap: () => ref.read(todayProvider.notifier).swap(),
                      ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _open(Exercise ex) => Navigator.of(context).push(bloomRoute(ReadyScreen(ex: ex)));

  /// Paw chips fly from the middle of the screen into the balance, then the
  /// balance counts up; filling the ring adds a burst and the bonus.
  Future<void> _playReward(Reward r) async {
    ref.read(pendingRewardProvider.notifier).set(null);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final chip = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    final target = chip == null ? Offset(size.width - 60, 70) : chip.localToGlobal(chip.size.center(Offset.zero));
    final from = Offset(size.width / 2, size.height * .62);
    const n = 5;
    for (var i = 0; i < n; i++) {
      FxLayer.fly(from + Offset((i - 2) * 22.0, 0), target, '+${(r.paws / n).round()}', delay: Duration(milliseconds: i * 110));
    }
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    ref.read(todayProvider.notifier).addPaws(r.paws);
    if (r.bonus > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      FxLayer.burst(Offset(size.width / 2, size.height * .45), count: 90);
      FxLayer.fly(from, target, '+${r.bonus}', delay: const Duration(milliseconds: 300));
      await Future<void>.delayed(const Duration(milliseconds: 1250));
      if (!mounted) return;
      ref.read(todayProvider.notifier).addPaws(r.bonus);
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: BloomColors.surface, borderRadius: BorderRadius.circular(BloomSpace.rPill), boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1))]),
        child: Text(text, style: BloomText.button.copyWith(fontSize: 14)),
      );
}

BoxDecoration get _cardDeco => BoxDecoration(
      color: BloomColors.surface,
      borderRadius: BorderRadius.circular(BloomSpace.rLg),
      boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1)), BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10))],
    );

class _PickCard extends StatelessWidget {
  const _PickCard({super.key, required this.ex, required this.onGo, required this.onSwap});
  final Exercise ex;
  final VoidCallback onGo, onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const _MoveTile(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HER PICK FOR YOU', style: BloomText.label),
              const SizedBox(height: 2),
              Text(ex.name, style: BloomText.headline),
              Text('${ex.meta} · +${ex.paws} paws', style: BloomText.caption),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        LedgeButton(label: 'Let’s do it together', onPressed: onGo, glow: true),
        const SizedBox(height: 6),
        Center(child: LedgeButton(label: 'Show me something else', onPressed: onSwap, variant: LedgeVariant.ghost, expand: false)),
      ]),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({super.key, required this.onMore});
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco,
        child: Column(children: [
          Text('DAY COMPLETE', style: BloomText.label),
          const SizedBox(height: 4),
          Text('That’s three today!', style: BloomText.title),
          const SizedBox(height: 10),
          const PopIn(delay: Duration(milliseconds: 300), child: EarnChip(text: '+15 bonus')),
          const SizedBox(height: 10),
          Text('Clover’s resting now. You can still do one more if you feel like it.', textAlign: TextAlign.center, style: BloomText.bodyMuted.copyWith(fontSize: 15)),
          const SizedBox(height: 14),
          LedgeButton(label: 'Do one more anyway', onPressed: onMore, variant: LedgeVariant.secondary),
        ]),
      );
}

/// Exercise tile with a little wiggle every few seconds.
class _MoveTile extends StatefulWidget {
  const _MoveTile();
  @override
  State<_MoveTile> createState() => _MoveTileState();
}

class _MoveTileState extends State<_MoveTile> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final a = t < .8 ? 0.0 : (t < .85 ? -.1 : t < .9 ? .1 : t < .95 ? -.05 : 0.0);
          return Transform.rotate(angle: a, child: child);
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
          child: const Icon(Icons.directions_run_rounded, color: BloomColors.sageDeep, size: 34),
        ),
      );
}
