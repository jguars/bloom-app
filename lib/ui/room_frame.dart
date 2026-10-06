import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/sfx.dart';
import '../app/theme.dart';
import '../data/today.dart';
import 'paw.dart';
import 'scene.dart';
import 'speech_bubble.dart';

/// Layout shared by the rooms: the room's scene on top fading into a
/// scrolling panel, Clover's line on the scene, and (Shop only) the paws chip.
class RoomFrame extends ConsumerWidget {
  const RoomFrame({
    super.key,
    required this.asset,
    required this.line,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showPaws = false,
    this.bubbleTop = 18,
    this.bubbleLeft = 16,
    this.pawsKey,
  });

  final String asset, line, title;
  final Widget subtitle;
  final List<Widget> children;
  final bool showPaws;
  final double bubbleTop, bubbleLeft;
  final Key? pawsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final sceneH = 300.0 + mq.padding.top * .5;
    final paws = ref.watch(todayProvider.select((s) => s.paws));
    return ColoredBox(
      color: BloomColors.surface,
      child: Stack(fit: StackFit.expand, children: [
        Positioned(left: 0, right: 0, top: 0, child: Scene(asset: asset, height: sceneH, fadeHeight: 62)),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Clover's line rides with the scene, so the panel never slides
            // under a pinned bubble.
            SliverToBoxAdapter(
              child: SizedBox(
                height: sceneH - 70,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(left: bubbleLeft, top: mq.padding.top + bubbleTop, child: IgnorePointer(child: SpeechBubble(text: line))),
                ]),
              ),
            ),
            // A soft lead-in so the panel's top edge never shows as a hard line
            // once it scrolls up over the art.
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00FFFBF3), BloomColors.surface],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: BloomColors.surface,
                padding: EdgeInsets.fromLTRB(16, 4, 16, 110 + mq.padding.bottom),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  RiseIn(child: Text(title, style: BloomText.display)),
                  const SizedBox(height: 2),
                  RiseIn(delay: const Duration(milliseconds: 60), child: subtitle),
                  const SizedBox(height: 16),
                  ...children,
                ]),
              ),
            ),
          ],
        ),
        if (showPaws) Positioned(right: 16, top: mq.padding.top + 12, child: PawChip(key: pawsKey, paws: paws)),
      ]),
    );
  }
}

/// Two or three peer views (design system: SegmentedSwitch).
class SegmentedSwitch extends StatelessWidget {
  const SegmentedSwitch({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / labels.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: const Cubic(.2, 1.3, .35, 1),
            left: index * w,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(color: BloomColors.surface, borderRadius: BorderRadius.circular(BloomSpace.rPill), boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 2))]),
            ),
          ),
          Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: BloomText.button.copyWith(fontSize: 15, color: i == index ? BloomColors.ink : BloomColors.inkMuted),
                        child: Text(labels[i]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Opens a design-system bottom sheet: surface, xl top corners, handle,
/// springy slide-up.
Future<T?> showBloomSheet<T>(BuildContext context, WidgetBuilder builder) {
  SfxPlayer.instance.play(Sfx.whoosh);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: BloomColors.ink.withValues(alpha: .45),
    sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 460), curve: Cubic(.2, 1.15, .35, 1), reverseDuration: Duration(milliseconds: 240)),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: BloomColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(BloomSpace.rXl)),
          boxShadow: [BoxShadow(color: Color(0x292E3826), blurRadius: 32, offset: Offset(0, -6))],
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 5, decoration: BoxDecoration(color: BloomColors.lineStrong, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 16),
          Builder(builder: builder),
        ]),
      ),
    ),
  );
}
