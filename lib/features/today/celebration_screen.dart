import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/exercises.dart';
import '../../data/today.dart';
import '../../ui/clover_scene.dart';
import '../../ui/day_ring.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import 'flow.dart';

/// The payoff: Clover leaps in the living room, confetti bursts three times,
/// and Collect sends the paws home to Today.
class CelebrationScreen extends ConsumerStatefulWidget {
  const CelebrationScreen({super.key, required this.ex, required this.reward});
  final Exercise ex;
  final Reward reward;

  @override
  ConsumerState<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends ConsumerState<CelebrationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      SfxPlayer.instance.play(Sfx.cheer);
      if (widget.reward.flag != null) Future<void>.delayed(const Duration(milliseconds: 900), () => SfxPlayer.instance.play(Sfx.flag));
      final size = MediaQuery.of(context).size;
      // The first burst lands at the top of her leap (about 0.45 s into CheerIntro), the next two follow it.
      for (final (dx, dy, wait, n) in [(.5, .26, 450, 80), (.22, .22, 320, 40), (.78, .24, 320, 40)]) {
        await Future<void>.delayed(Duration(milliseconds: wait));
        if (!mounted) return;
        FxLayer.burst(Offset(size.width * dx, size.height * dy), count: n);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sceneH = (mq.size.height * .55).clamp(380.0, 500.0);
    return Scaffold(
      backgroundColor: BloomColors.surface,
      body: Stack(fit: StackFit.expand, children: [
        // The back garden at golden hour; she starts her leap as soon as the scene is up.
        Positioned(left: 0, right: 0, top: 0, child: CloverSceneView(scene: CloverScene.cheer, height: sceneH, cheering: true, fadeHeight: 80)),
        Positioned.fill(
          top: sceneH - 20,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + mq.padding.bottom),
            child: Column(children: [
              PopIn(child: Text('We did that together!', textAlign: TextAlign.center, style: BloomText.display)),
              const SizedBox(height: 6),
              RiseIn(delay: const Duration(milliseconds: 150), child: Text('${widget.ex.name} · ${widget.ex.minutesText}', style: BloomText.caption.copyWith(fontSize: 15))),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (widget.reward.paws > 0) PopIn(delay: const Duration(milliseconds: 260), child: EarnChip(text: '+${widget.reward.paws}')),
                if (widget.reward.credit == MoveCredit.daily) ...[
                  const SizedBox(width: 12),
                  PopIn(delay: const Duration(milliseconds: 340), child: DayRing(done: widget.reward.doneNow)),
                ],
              ]),
              if (widget.reward.flag != null) ...[
                const SizedBox(height: 12),
                PopIn(
                  delay: const Duration(milliseconds: 900),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: BloomColors.mustardSoft, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.flag_rounded, size: 18, color: BloomColors.mustardPress),
                      const SizedBox(width: 6),
                      Text('New flag: ${widget.reward.flag!.tag} · ${widget.reward.flag!.title}', style: BloomText.button.copyWith(fontSize: 15)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              RiseIn(
                delay: const Duration(milliseconds: 420),
                child: Text(
                  switch (widget.reward.credit) {
                    MoveCredit.extra => 'A bonus move! Half paws, full smiles.',
                    MoveCredit.fun => 'Just for fun. Clover loved that.',
                    MoveCredit.daily => widget.reward.doneNow >= kDailyGoal ? 'All three! Clover is beaming.' : 'Clover is a little lighter on her feet.',
                  },
                  textAlign: TextAlign.center,
                  style: BloomText.bodyMuted,
                ),
              ),
              const Spacer(),
              RiseIn(
                delay: const Duration(milliseconds: 500),
                child: LedgeButton(
                  label: widget.reward.paws > 0 ? 'Collect ${widget.reward.paws}' : 'Back to Today',
                  variant: LedgeVariant.reward,
                  glow: true,
                  leading: widget.reward.paws > 0 ? const PawIcon(color: BloomColors.ink, size: 20) : null,
                  onPressed: () {
                    ref.read(pendingRewardProvider.notifier).set(widget.reward);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
