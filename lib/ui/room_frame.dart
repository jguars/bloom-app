import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/feel.dart';
import '../app/sfx.dart';
import '../app/theme.dart';
import '../data/today.dart';
import '../app/shell.dart';
import 'clover_rive.dart';
import 'clover_scene.dart';
import 'paw.dart';
import 'room_visit.dart';
import 'scene.dart';
import 'speech_bubble.dart';

/// Layout shared by the rooms: the room's scene on top fading into a
/// scrolling panel, Clover's line on the scene, and (Shop only) the paws chip.
/// With a [scene], the room is a taller live Rive scene the roaming Clover visits
/// (empty at first, she walks in and plays [action]); her line pops in over her
/// head once she's there.
class RoomFrame extends ConsumerStatefulWidget {
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
    this.scene,
    this.action,
    this.room,
    this.head,
    this.sceneOverlay,
    this.pinned,
    this.topLeft,
    this.titleTrailing,
  });

  final String asset, line, title;
  final Widget subtitle;
  final List<Widget> children;
  final bool showPaws;
  final double bubbleTop, bubbleLeft;
  final Key? pawsKey;
  final CloverScene? scene;
  final CloverAction? action;

  /// The tab this room is (with [scene]: each opening is a new visit).
  final Room? room;

  /// Where her head is when her spot varies (artboard units); defaults to the scene's.
  final Offset? head;

  /// Painted over the scene's art (e.g. the hallway's portraits), sized to the scene.
  final Widget? sceneOverlay;

  /// When set, the scene and a pane with the title, subtitle and these widgets (e.g. the Shop's
  /// sub-panel switch) stay frozen, and only [children] scroll, sliding away under the pane.
  final List<Widget>? pinned;

  /// A small button pinned to the scene's top-left corner (e.g. the Profile's settings gear).
  final Widget? topLeft;

  /// Sits on the title's row, at the right (e.g. the Plan's photo check).
  final Widget? titleTrailing;

  @override
  ConsumerState<RoomFrame> createState() => _RoomFrameState();
}

class _RoomFrameState extends ConsumerState<RoomFrame> with RoomVisit {
  @override
  Room get visitRoom => widget.room!;

  /// Her line. Over a live scene the tail tips toward the top of her head, and the bubble hangs on
  /// whichever side of her has room, never running off the screen; otherwise it's pinned top-left.
  Widget _bubble(Offset? head, String line, double sceneH, MediaQueryData mq) {
    if (head == null) {
      return Positioned(left: widget.bubbleLeft, top: mq.padding.top + widget.bubbleTop, child: IgnorePointer(child: SpeechBubble(text: line)));
    }
    final bottom = sceneH - 70 - head.dy + 6;
    final onLeft = head.dx > mq.size.width * .5;
    return Positioned(
      left: onLeft ? 16 : head.dx - 5,
      right: onLeft ? mq.size.width - head.dx - 5 : 16,
      bottom: bottom,
      child: IgnorePointer(
        child: Align(
          alignment: onLeft ? Alignment.bottomRight : Alignment.bottomLeft,
          child: ArrivedPop(
            shown: arrived,
            alignment: onLeft ? Alignment.bottomRight : Alignment.bottomLeft,
            child: SpeechBubble(text: line, tailRight: onLeft),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RoomFrame(:asset, :line, :title, :subtitle, :children, :showPaws, :bubbleTop, :bubbleLeft, :pawsKey, :scene) = widget;
    final mq = MediaQuery.of(context);
    if (scene != null) watchVisits();
    final sceneH = scene != null ? (mq.size.height * .47).clamp(340.0, 470.0) : 300.0 + mq.padding.top * .5;
    final head = scene?.headIn(Size(mq.size.width, sceneH), widget.head);
    final paws = ref.watch(todayProvider.select((s) => s.paws));
    return ColoredBox(
      color: BloomColors.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: scene != null
                ? CloverSceneView(key: ValueKey('${widget.action}-$visit'), scene: scene, height: sceneH, action: widget.action, overlay: widget.sceneOverlay, fadeHeight: 72)
                : Scene(asset: asset, height: sceneH, fadeHeight: 62),
          ),
          if (widget.pinned case final pinned?)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: sceneH - 70,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _bubble(head, line, sceneH, mq),
                    ],
                  ),
                ),
                const _LeadIn(),
                Container(
                  color: BloomColors.surface,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RiseIn(child: Row(children: [Expanded(child: Text(title, style: BloomText.display)), ?widget.titleTrailing])),
                      const SizedBox(height: 2),
                      RiseIn(delay: const Duration(milliseconds: 60), child: subtitle),
                      const SizedBox(height: 16),
                      ...pinned,
                    ],
                  ),
                ),
                // Only the items scroll; they slip under the pane (softly, through a short fade).
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 110 + mq.padding.bottom),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 16,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [BloomColors.surface, Color(0x00FFFBF3)]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Clover's line rides with the scene, so the panel never slides
                // under a pinned bubble.
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: sceneH - 70,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _bubble(head, line, sceneH, mq),
                      ],
                    ),
                  ),
                ),
                // A soft lead-in so the panel's top edge never shows as a hard line
                // once it scrolls up over the art.
                const SliverToBoxAdapter(child: _LeadIn()),
                SliverToBoxAdapter(
                  child: Container(
                    color: BloomColors.surface,
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 110 + mq.padding.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RiseIn(child: Row(children: [Expanded(child: Text(title, style: BloomText.display)), ?widget.titleTrailing])),
                        const SizedBox(height: 2),
                        RiseIn(delay: const Duration(milliseconds: 60), child: subtitle),
                        const SizedBox(height: 16),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (widget.topLeft case final tl?) Positioned(left: 16, top: mq.padding.top + 12, child: tl),
          if (showPaws)
            Positioned(
              right: 16,
              top: mq.padding.top + 12,
              child: PawChip(key: pawsKey, paws: paws),
            ),
        ],
      ),
    );
  }
}

/// The soft fade from the scene into the panel, so the panel's top edge never shows as a line.
class _LeadIn extends StatelessWidget {
  const _LeadIn();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 40,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFBF3), BloomColors.surface]),
      ),
    ),
  );
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
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: const Cubic(.2, 1.3, .35, 1),
                left: index * w,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: BloomColors.surface,
                    borderRadius: BorderRadius.circular(BloomSpace.rPill),
                    boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 2))],
                  ),
                ),
              ),
              Row(
                children: [
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
                ],
              ),
            ],
          );
        },
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(color: BloomColors.lineStrong, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Builder(builder: builder),
          ],
        ),
      ),
    ),
  );
}

/// Sub-panels you can also flip with a swipe: left for the next one, right for the previous
/// (the same [index]/[onChanged] as the [SegmentedSwitch] above them).
class SwipePanels extends StatelessWidget {
  const SwipePanels({super.key, required this.index, required this.count, required this.onChanged, required this.child});
  final int index, count;
  final ValueChanged<int> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragEnd: (d) {
      final v = d.primaryVelocity ?? 0;
      final to = v < -200
          ? index + 1
          : v > 200
          ? index - 1
          : index;
      if (to != index && to >= 0 && to < count) {
        Feel.selectionClick();
        onChanged(to);
      }
    },
    child: child,
  );
}

/// The slide for two swiped panels (keyed `ValueKey(0)` and `ValueKey(1)`): the first lives on the
/// left and the second on the right, so each comes in from, and leaves towards, its own side.
Widget panelTransition(Widget c, Animation<double> a) => FadeTransition(
  opacity: a,
  child: SlideTransition(
    position: Tween(begin: Offset((c.key as ValueKey<int>).value == 0 ? -.1 : .1, 0), end: Offset.zero).animate(a),
    child: c,
  ),
);
