import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/equipment.dart';
import '../../data/today.dart';
import '../../ui/fx_layer.dart';
import '../../ui/gear_art.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/scene.dart';
import '../today/flow.dart';
import '../today/ready_screen.dart';

/// New gear! Confetti in the garage and the two moves it unlocks.
class UnlockedScreen extends ConsumerStatefulWidget {
  const UnlockedScreen({super.key, required this.item});
  final Equipment item;

  @override
  ConsumerState<UnlockedScreen> createState() => _UnlockedScreenState();
}

class _UnlockedScreenState extends ConsumerState<UnlockedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final size = MediaQuery.of(context).size;
      for (final (dx, dy, n) in [(.5, .25, 90), (.2, .2, 40), (.8, .22, 40)]) {
        if (!mounted) return;
        FxLayer.burst(Offset(size.width * dx, size.height * dy), count: n);
        await Future<void>.delayed(const Duration(milliseconds: 330));
      }
    });
  }

  void _tryIt() {
    final first = widget.item.unlocks.first;
    ref.read(todayProvider.notifier).pickExercise(first);
    ref.read(roomProvider.notifier).go(Room.today);
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(bloomRoute(ReadyScreen(ex: first)));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sceneH = (mq.size.height * .47).clamp(340.0, 440.0);
    return Scaffold(
      backgroundColor: BloomColors.surface,
      body: Stack(fit: StackFit.expand, children: [
        Positioned(left: 0, right: 0, top: 0, child: Scene(asset: 'assets/scenes/garage.jpg', height: sceneH, fadeHeight: 90)),
        Positioned.fill(
          top: sceneH - 20,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + mq.padding.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Text('NEW GEAR', style: BloomText.label)),
              const SizedBox(height: 4),
              PopIn(child: Text('${widget.item.name} unlocked!', textAlign: TextAlign.center, style: BloomText.display)),
              const SizedBox(height: 16),
              for (final (i, ex) in widget.item.unlocks.indexed) ...[
                RiseIn(
                  delay: Duration(milliseconds: 300 + 120 * i),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: BloomColors.surface,
                      borderRadius: BorderRadius.circular(BloomSpace.rMd),
                      boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1)), BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rSm)), child: Center(child: GearArt(id: widget.item.id, width: 36))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ex.name, style: BloomText.headline.copyWith(fontSize: 16)),
                          Text('${ex.meta} · +${ex.paws} paws', style: BloomText.caption),
                        ]),
                      ),
                      const PopIn(delay: Duration(milliseconds: 700), child: _NewTag()),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const Spacer(),
              LedgeButton(label: 'Try it with Clover', glow: true, onPressed: _tryIt),
              const SizedBox(height: 6),
              Center(child: LedgeButton(label: 'Back to the gym', variant: LedgeVariant.ghost, expand: false, onPressed: () => Navigator.of(context).pop())),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _NewTag extends StatelessWidget {
  const _NewTag();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
        child: Text('NEW', style: BloomText.label.copyWith(color: BloomColors.forest)),
      );
}
