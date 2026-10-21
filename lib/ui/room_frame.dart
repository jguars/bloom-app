import 'dart:math' as math;

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
    this.night = false,
    this.pinned,
    this.topLeft,
    this.topRight,
    this.titleTrailing,
    this.line2,
    this.onSceneTap,
    this.panel,
    this.titleBlock = 92,
  });

  final String asset, line, title;

  /// A second thing Clover says, in turn with [line].
  final String? line2;
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

  /// After dark (rooms painted by night too).
  final bool night;

  /// When set, the room collapses as its list scrolls: the scene goes, the title docks as a slim bar, and these
  /// widgets (e.g. the Shop's sub-panel switch; may be empty) dock under it, so the list gets most of the screen.
  final List<Widget>? pinned;

  /// A small button pinned to the scene's top-left corner (e.g. the Profile's settings gear).
  final Widget? topLeft;

  /// A small chip pinned to the scene's top-right corner (e.g. the Progress streak).
  final Widget? topRight;

  /// Sits on the title's row, at the right (e.g. the Plan's photo check).
  final Widget? titleTrailing;

  /// A tap on the scene (where the panel doesn't cover it), at that point on the scene.
  final ValueChanged<Offset>? onSceneTap;

  /// Which sub-panel is showing, with [pinned]: switching it while docked keeps the room collapsed.
  final Object? panel;

  /// With [pinned]: the open title block's height (taller for a subtitle row with a button).
  final double titleBlock;

  /// How tall a live scene is on this screen.
  static double sceneHeight(MediaQueryData mq) => (mq.size.height * .47).clamp(340.0, 470.0);

  @override
  ConsumerState<RoomFrame> createState() => _RoomFrameState();
}

class _RoomFrameState extends ConsumerState<RoomFrame> with RoomVisit {
  @override
  Room get visitRoom => widget.room!;

  final _scroll = ScrollController();

  @override
  void didUpdateWidget(RoomFrame old) {
    super.didUpdateWidget(old);
    // A new panel while docked starts at the top of the docked list, not back at the scene.
    if (widget.panel != old.panel && _scroll.hasClients) {
      final mq = MediaQuery.of(context);
      final docked = RoomFrame.sceneHeight(mq) - 70 + DockHeader.travel(mq.padding.top, widget.titleBlock);
      if (_scroll.offset > docked) _scroll.jumpTo(docked);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Her line. Over a live scene the tail tips toward the top of her head, and the bubble hangs on
  /// whichever side of her has room, never running off the screen; otherwise it's pinned top-left.
  Widget _bubble(Offset? head, String line, double sceneH, MediaQueryData mq) {
    if (head == null) {
      return Positioned(
        left: widget.bubbleLeft,
        top: mq.padding.top + widget.bubbleTop,
        child: IgnorePointer(child: SpeechBubble(text: line, alternate: widget.line2)),
      );
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
            child: SpeechBubble(text: line, alternate: widget.line2, tailRight: onLeft),
          ),
        ),
      ),
    );
  }

  /// Passes taps on the open part of the scene to [RoomFrame.onSceneTap], in the scene's own
  /// coordinates (the scene sits at the top of the room, whatever the scroll).
  Widget _sceneTaps(Widget child) {
    final onTap = widget.onSceneTap;
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) onTap(box.globalToLocal(d.globalPosition));
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final RoomFrame(:asset, :line, :title, :subtitle, :children, :showPaws, :bubbleTop, :bubbleLeft, :pawsKey, :scene) = widget;
    final mq = MediaQuery.of(context);
    if (scene != null) watchVisits();
    final sceneH = scene != null ? RoomFrame.sceneHeight(mq) : 300.0 + mq.padding.top * .5;
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
            child: scene != null && !onShow
                ? SizedBox(height: sceneH)
                : scene != null
                ? CloverSceneView(key: ValueKey('${widget.action}-$visit'), scene: scene, height: sceneH, action: widget.action, overlay: widget.sceneOverlay, night: widget.night, fadeHeight: 72)
                : Scene(asset: asset, height: sceneH, fadeHeight: 62),
          ),
          if (widget.pinned case final pinned?)
            // The room collapses as the list scrolls: the scene and subtitle go, the title shrinks into a
            // slim bar, and the [pinned] switch docks under it, so the list gets most of the screen.
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _sceneTaps(SizedBox(
                    height: sceneH - 70,
                    child: Stack(clipBehavior: Clip.none, children: [_bubble(head, line, sceneH, mq)]),
                  )),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: DockHeader(
                    title: title,
                    subtitle: subtitle,
                    trailing: widget.titleTrailing,
                    pinned: pinned,
                    top: mq.padding.top,
                    // Room on the slim bar for what floats in the top corners already (paw chip, streak, settings).
                    trailingGap: showPaws ? 110 : (widget.topRight != null ? 96 : 0),
                    leadingGap: widget.topLeft != null ? 56 : 0,
                    titleBlock: widget.titleBlock,
                  ),
                ),
                // The list on solid paper, down to the bottom of the screen, so the scene never shows
                // through as it passes.
                SliverToBoxAdapter(
                  child: Container(
                    color: BloomColors.surface,
                    // Never shorter than the screen under the docked bar, so even a short page can tuck the room away.
                    constraints: BoxConstraints(minHeight: DockHeader.listMin(mq, pinned.isNotEmpty)),
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 110 + mq.padding.bottom),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
                ),
                const SliverFillRemaining(hasScrollBody: false, child: ColoredBox(color: BloomColors.surface)),
              ],
            )
          else
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Clover's line rides with the scene, so the panel never slides
                // under a pinned bubble.
                SliverToBoxAdapter(
                  child: _sceneTaps(SizedBox(
                    height: sceneH - 70,
                    child: Stack(clipBehavior: Clip.none, children: [_bubble(head, line, sceneH, mq)]),
                  )),
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
                        RiseIn(
                          child: Row(
                            children: [
                              Expanded(child: Text(title, style: BloomText.display)),
                              ?widget.titleTrailing,
                            ],
                          ),
                        ),
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
          if (widget.topRight case final tr?) Positioned(right: 16, top: mq.padding.top + 12, child: tr),
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

/// The title and the [pinned] switch of a collapsing room (Shop, Plan, Progress, Profile, and Today's own
/// layout). Open, it's the soft lead-in from the scene, the big title and subtitle, then the switch (if any). As the
/// list scrolls it shrinks: the big title fades into a slim bar at the top of the screen, and the switch docks
/// under it. [leadingGap] and [trailingGap] keep the slim bar clear of buttons floating in the top corners.
class DockHeader extends SliverPersistentHeaderDelegate {
  DockHeader({required this.title, required this.subtitle, required this.trailing, required this.pinned, required this.top, this.trailingGap = 0, this.leadingGap = 0, this.keepTrailing = false, this.titleBlock = 92, this.trailingBeside = false});
  final String title;

  /// Keep [trailing] on the slim bar even beside a floating corner chip (Today's craving button).
  final bool keepTrailing;

  /// Open, [trailing] sits beside the title and subtitle together, centred on both (a big round button).
  final bool trailingBeside;
  final Widget subtitle;
  final Widget? trailing;
  final List<Widget> pinned;
  final double top, trailingGap, leadingGap;

  /// The open title and subtitle's height (taller when the title row carries a big button).
  final double titleBlock;

  static const _lead = 40.0, _bar = 56.0;
  double get _switch => pinned.isEmpty ? 0 : 64.0;
  static double _open(double top, double block) => math.max(_lead + block, top + _bar + 8);

  /// The least height a docking room's list needs to scroll the room fully away (the screen under the docked bar).
  static double listMin(MediaQueryData mq, bool withSwitch) => mq.size.height - (mq.padding.top + _bar + (withSwitch ? 64 : 0));

  /// How far the header shrinks between open and docked.
  static double travel(double top, [double block = 92]) => _open(top, block) - (top + _bar);

  @override
  double get maxExtent => _open(top, titleBlock) + _switch;
  @override
  double get minExtent => top + _bar + _switch;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / travel(top, titleBlock)).clamp(0.0, 1.0);
    final big = (1 - t * 1.8).clamp(0.0, 1.0), slim = ((t - .55) / .45).clamp(0.0, 1.0);
    return Stack(fit: StackFit.expand, children: [
      // Solid under the title and switch; above them, the soft lead-in from the scene, which fills in
      // as the room docks.
      Positioned(left: 0, right: 0, bottom: 0, top: _lead * (1 - t), child: const ColoredBox(color: BloomColors.surface)),
      if (t < 1)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _lead * (1 - t) + 1,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFBF3), BloomColors.surface]),
              ),
            ),
          ),
        ),
      // The big title and subtitle, sliding up and fading as it shrinks.
      Positioned(
        left: 16,
        right: 16,
        bottom: _switch,
        height: titleBlock,
        child: IgnorePointer(
          ignoring: big < .5,
          child: Opacity(
            opacity: big,
            child: Transform.translate(
              offset: Offset(0, -12 * t),
              child: trailingBeside
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.end, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            RiseIn(child: Text(title, style: BloomText.display)),
                            const SizedBox(height: 2),
                            RiseIn(delay: const Duration(milliseconds: 60), child: subtitle),
                          ]),
                        ),
                        ?trailing,
                      ]),
                      const SizedBox(height: 16),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.end, children: [
                      RiseIn(child: Row(children: [Expanded(child: Text(title, style: BloomText.display)), ?trailing])),
                      const SizedBox(height: 2),
                      RiseIn(delay: const Duration(milliseconds: 60), child: subtitle),
                      const SizedBox(height: 16),
                    ]),
            ),
          ),
        ),
      ),
      // The slim bar, once docked.
      if (slim > 0)
        Positioned(
          left: 16 + leadingGap,
          right: 16 + trailingGap,
          top: top,
          height: _bar,
          child: Opacity(
            opacity: slim,
            child: Row(children: [
              Expanded(child: Text(title, style: BloomText.title.copyWith(fontSize: 22), maxLines: 1, softWrap: false, overflow: TextOverflow.fade)),
              if (trailingGap == 0) ?trailing,
              // a big button kept on the slim bar shrinks to fit it
              if (trailingGap != 0 && keepTrailing && trailing != null) ...[
                const SizedBox(width: 8),
                SizedBox(height: 42, child: FittedBox(child: trailing)),
              ],
            ]),
          ),
        ),
      Positioned(
        left: 16,
        right: 16,
        bottom: 8,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: pinned),
      ),
      // A hairline under the docked switch, so the list reads as passing beneath it.
      Positioned(left: 0, right: 0, bottom: 0, height: 1, child: Opacity(opacity: slim, child: const ColoredBox(color: BloomColors.line))),
    ]);
  }

  @override
  bool shouldRebuild(DockHeader old) =>
      old.title != title || old.subtitle != subtitle || old.trailing != trailing || old.pinned != pinned || old.top != top ||
      old.trailingGap != trailingGap || old.leadingGap != leadingGap || old.keepTrailing != keepTrailing || old.titleBlock != titleBlock ||
      old.trailingBeside != trailingBeside;
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
