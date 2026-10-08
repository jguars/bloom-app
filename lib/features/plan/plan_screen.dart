import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock.dart';
import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/plan.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../today/flow.dart';
import '../food/food_check_screen.dart';
import 'rule_sheet.dart';

/// The balcony garden: the Do's and the Don'ts, a swipe apart. Each list keeps what's up next on
/// top (the most frequent first); a logged rule sinks to the bottom, and a repeatable one floats
/// back up after its rest.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  int _tab = 0;
  Timer? _back;
  DateTime? _backAt;

  /// While a rule rests, rebuilds each minute (for its "back up in" countdown) and when it's due.
  void _wake(Plan plan, DateTime now) {
    final back = plan.nextBack(now);
    final tick = now.add(const Duration(minutes: 1));
    final at = back == null ? null : (back.isBefore(tick) ? back : tick);
    if (at == _backAt) return;
    _back?.cancel();
    _backAt = at;
    if (at != null) {
      _back = Timer(at.difference(now) + const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _backAt = null);
      });
    }
  }

  @override
  void dispose() {
    _back?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final now = ref.watch(clockProvider)();
    _wake(plan, now);
    final logs = plan.logCount;
    final next = plan.upNext(PlanKind.more, now).firstOrNull;
    final line = plan.rules.isEmpty
        ? 'Let’s plant our first habit!'
        : logs == 0
            ? 'Watering our good habits!'
            : next == null
                ? 'All caught up. We’re blooming!'
                : '${next.title}? I’m in!';
    return RoomFrame(
      asset: 'assets/scenes/balcony.jpg',
      scene: CloverScene.plan,
      action: CloverAction.balconyWater,
      room: Room.plan,
      line: line,
      title: 'Plan',
      panel: _tab,
      line2: 'Small swaps add up. You’ve got this.',
      titleTrailing: const _PhotoCheckButton(),
      subtitle: AnimatedSwitcher(
        duration: BloomMotion.base,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
        child: Text(
          logs == 0 ? 'Nothing logged yet today' : '$logs logged today · +${plan.pawsToday} paws',
          key: ValueKey(logs),
          style: BloomText.bodyMuted.copyWith(fontSize: 15),
        ),
      ),
      // The scene, title and switch stay put; only the lists scroll, under them.
      pinned: [
        SegmentedSwitch(labels: const ['Do’s', 'Don’ts'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
      ],
      children: [
        SwipePanels(
          index: _tab,
          count: 2,
          onChanged: (i) => setState(() => _tab = i),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            transitionBuilder: panelTransition,
            child: _Panel(key: ValueKey(_tab), kind: PlanKind.values[_tab], plan: plan, now: now),
          ),
        ),
      ],
    );
  }
}

/// One list. Rows sit in fixed slots so that when one is logged it can glide down to its new place
/// (after a beat, so the tick lands first).
class _Panel extends StatefulWidget {
  const _Panel({super.key, required this.kind, required this.plan, required this.now});
  final PlanKind kind;
  final Plan plan;
  final DateTime now;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  static const _row = 76.0, _card = 66.0, _header = 30.0, _gap = 10.0;
  _Layout? _held;
  Timer? _release;

  _Layout _layout() {
    final p = widget.plan;
    final up = p.upNext(widget.kind, widget.now), down = p.logged(widget.kind, widget.now);
    final y = <String, double>{};
    var h = _header;
    for (final r in up) {
      y[r.id] = h;
      h += _row;
    }
    double? second;
    if (down.isNotEmpty) {
      second = h + _gap;
      h = second + _header;
      for (final r in down) {
        y[r.id] = h;
        h += _row;
      }
    }
    return _Layout(y, second, h, up.isEmpty);
  }

  void _logged() {
    _release?.cancel();
    setState(() => _held = _layout());
    _release = Timer(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _held = null);
    });
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final more = widget.kind == PlanKind.more;
    final rules = widget.plan.of(widget.kind);
    final live = _layout();
    final at = _held ?? live;
    const curve = Cubic(.2, 1.1, .35, 1);
    const move = Duration(milliseconds: 520);
    final add = LedgeButton(
      label: more ? 'Add a Do' : 'Add a Don’t',
      variant: LedgeVariant.secondary,
      leading: const Icon(Icons.add_rounded, color: BloomColors.ink),
      onPressed: () => showBloomSheet<void>(context, (c) => RuleSheet(kind: widget.kind)),
    );
    if (rules.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
          child: Text(
            more ? 'Add something small you’d like to do more of, like a glass of water.' : 'Add one thing you’d like to say no to, like sugary drinks.',
            style: BloomText.bodyMuted.copyWith(fontSize: 15),
          ),
        ),
        const SizedBox(height: 16),
        add,
      ]);
    }
    Widget header(String text, double? top) => AnimatedPositioned(
          duration: move,
          curve: curve,
          left: 2,
          right: 0,
          top: top ?? at.height,
          height: _header,
          child: AnimatedOpacity(
            duration: BloomMotion.base,
            opacity: top == null ? 0 : 1,
            child: Text(text, style: BloomText.label),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedContainer(
        duration: move,
        curve: curve,
        height: at.height,
        child: Stack(clipBehavior: Clip.none, children: [
          header(at.allDone ? (more ? 'ALL CAUGHT UP' : 'ALL RESISTED FOR NOW') : (more ? 'UP NEXT' : 'RESIST NEXT'), 0),
          header('LOGGED TODAY', at.second),
          for (final r in rules)
            AnimatedPositioned(
              key: ValueKey(r.id),
              duration: move,
              curve: curve,
              left: 0,
              right: 0,
              top: at.y[r.id] ?? live.y[r.id] ?? 0,
              height: _card,
              child: _RuleRow(
                rule: r,
                count: widget.plan.count(r.id),
                due: widget.plan.isDue(r, widget.now),
                backAt: widget.plan.backAt(r),
                now: widget.now,
                onLogged: _logged,
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      add,
    ]);
  }
}

class _Layout {
  const _Layout(this.y, this.second, this.height, this.allDone);
  final Map<String, double> y;
  final double? second;
  final double height;
  final bool allDone;
}

class _RuleRow extends ConsumerStatefulWidget {
  const _RuleRow({required this.rule, required this.count, required this.due, required this.backAt, required this.now, required this.onLogged});
  final PlanRule rule;
  final int count;
  final bool due;
  final DateTime? backAt;
  final DateTime now;
  final VoidCallback onLogged;

  @override
  ConsumerState<_RuleRow> createState() => _RuleRowState();
}

class _RuleRowState extends ConsumerState<_RuleRow> {
  final _buttonKey = GlobalKey();

  void _fly(int paws) {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final c = box.localToGlobal(box.size.center(Offset.zero));
    FxLayer.fly(c, c + const Offset(-30, -150), paws > 0 ? '+$paws' : 'Logged');
    if (paws > 0) FxLayer.burst(c, count: 14, power: .45);
  }

  /// A repeatable rule: one more log, with an undo, since the card slips away from under the finger.
  void _log() {
    final notifier = ref.read(planProvider.notifier);
    final r = widget.rule;
    Feel.lightImpact();
    SfxPlayer.instance.play(Sfx.check);
    _fly(notifier.log(r.id));
    widget.onLogged();
    final n = ref.read(planProvider).count(r.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(_snack(
      r.kind == PlanKind.more ? '${r.title} · $n today' : 'Said no · ${r.title.toLowerCase()} · $n today',
      'Undo',
      () => notifier.unlog(r.id),
    ));
  }

  /// A once-a-day rule: a tick, or untick.
  void _tick() {
    final on = ref.read(planProvider.notifier).toggle(widget.rule.id);
    if (on) {
      Feel.lightImpact();
      SfxPlayer.instance.play(Sfx.check);
      _fly(kPawsPerRule);
    } else {
      Feel.selectionClick();
      SfxPlayer.instance.play(Sfx.uncheck);
    }
    widget.onLogged();
  }

  SnackBar _snack(String text, String action, VoidCallback onAction) => SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        persist: false,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        backgroundColor: BloomColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd)),
        content: Text(text, style: BloomText.body.copyWith(color: BloomColors.surface), maxLines: 1, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(label: action, textColor: BloomColors.mustard, onPressed: onAction),
      );

  String _meta() {
    final r = widget.rule, n = widget.count, more = r.kind == PlanKind.more;
    if (!r.repeats) return n > 0 ? (more ? 'Done today · +$kPawsPerRule paws' : 'Kept today · +$kPawsPerRule paws') : (more ? 'Once a day' : 'All day');
    final said = more ? '' : 'Said no ';
    if (n >= r.goal) return '$said$n today · goal met';
    if (!widget.due && widget.backAt != null) return 'Back up in ${_until(widget.backAt!.difference(widget.now))}';
    return '$said$n of ${r.goal} today';
  }

  static String _until(Duration d) {
    final m = (d.inSeconds / 60).ceil().clamp(1, 24 * 60);
    return m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rule;
    final more = r.kind == PlanKind.more;
    final (tint, deep) = more ? (BloomColors.forestSoft, BloomColors.forest) : (BloomColors.claySoft, BloomColors.clayDeep);
    final dim = !widget.due;
    // No swipe-to-remove: a swipe always switches between the Do's and the Don'ts. Removing lives
    // in the edit sheet.
    return GestureDetector(
      onTap: () => showBloomSheet<void>(context, (c) => RuleSheet(editing: r)),
      child: AnimatedContainer(
        duration: BloomMotion.base,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: dim ? BloomColors.paper : BloomColors.surface,
          borderRadius: BorderRadius.circular(BloomSpace.rMd),
          boxShadow: dim
              ? const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1))]
              : const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1)), BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Row(children: [
          AnimatedOpacity(
            duration: BloomMotion.base,
            opacity: dim ? .65 : 1,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
              child: Icon(iconFor(r.icon), color: deep, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedDefaultTextStyle(
                duration: BloomMotion.base,
                style: BloomText.headline.copyWith(fontSize: 16, height: 22 / 16, color: dim ? BloomColors.inkMuted : BloomColors.ink),
                child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 2),
              Row(children: [
                if (r.repeats && r.goal <= 12) ...[
                  for (var i = 0; i < r.goal; i++)
                    AnimatedContainer(
                      duration: BloomMotion.base,
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(color: i < widget.count ? deep : BloomColors.line, borderRadius: BorderRadius.circular(3)),
                    ),
                  const SizedBox(width: 4),
                ],
                Flexible(child: Text(_meta(), style: BloomText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          KeyedSubtree(
            key: _buttonKey,
            child: r.repeats
                ? _LogButton(count: widget.count, due: widget.due, more: more, label: r.title, onTap: _log)
                : _Check(on: widget.count > 0, skip: !more, onTap: _tick, label: r.title),
          ),
        ]),
      ),
    );
  }
}

/// "+1" (or "+ No" for a Don't): filled while the rule is up next, outlined while it rests.
class _LogButton extends StatelessWidget {
  const _LogButton({required this.count, required this.due, required this.more, required this.label, required this.onTap});
  final int count;
  final bool due, more;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deep = more ? BloomColors.forest : BloomColors.clayDeep;
    final fill = !due ? BloomColors.surface : (more ? BloomColors.forest : BloomColors.claySoft);
    final fg = due && more ? BloomColors.onForest : deep;
    final ledge = due && more ? BloomColors.forestPress : (due ? BloomColors.clayDeep.withValues(alpha: .35) : BloomColors.line);
    return Semantics(
      button: true,
      label: more ? 'Log $label' : 'Said no to $label',
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(count),
          tween: Tween(begin: count > 0 ? .75 : 1, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: BloomMotion.pop,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: AnimatedContainer(
            duration: BloomMotion.fast,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: deep, width: 2),
              boxShadow: [BoxShadow(color: ledge, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, color: fg, size: 18, weight: 700),
              const SizedBox(width: 2),
              Text(more ? '1' : 'No', style: BloomText.button.copyWith(fontSize: 15, color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The tick box: pops when ticked, on a little ledge.
class _Check extends StatelessWidget {
  const _Check({required this.on, required this.skip, required this.onTap, required this.label});
  final bool on, skip;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fill = on ? (skip ? BloomColors.claySoft : BloomColors.forest) : BloomColors.surface;
    final fg = on ? (skip ? BloomColors.clayDeep : BloomColors.onForest) : BloomColors.lineStrong;
    return Semantics(
      checked: on,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(on),
          tween: Tween(begin: on ? .7 : 1, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: BloomMotion.pop,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: AnimatedContainer(
            duration: BloomMotion.fast,
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? (skip ? BloomColors.clayDeep : BloomColors.forest) : BloomColors.lineStrong, width: 2),
              boxShadow: [BoxShadow(color: on && !skip ? BloomColors.forestPress : BloomColors.line, offset: const Offset(0, 3))],
            ),
            child: Icon(skip ? Icons.close_rounded : Icons.check_rounded, color: fg, size: 22, weight: 700),
          ),
        ),
      ),
    );
  }
}

/// "On my plan?": a deep-sky pill with a camera badge, opposite the Plan title. Opens the photo check.
class _PhotoCheckButton extends StatelessWidget {
  const _PhotoCheckButton();

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Is this on my plan? Check a photo',
        child: GestureDetector(
          onTap: () {
            Feel.selectionClick();
            Navigator.of(context).push(bloomRoute(const FoodCheckScreen()));
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
            decoration: BoxDecoration(
              color: BloomColors.skyDeep,
              borderRadius: BorderRadius.circular(BloomSpace.rPill),
              boxShadow: const [BoxShadow(color: Color(0x3324485A), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle),
                child: const Icon(Icons.photo_camera_outlined, size: 19, color: BloomColors.skyDeep),
              ),
              const SizedBox(width: 8),
              Text('On my plan?', style: BloomText.button.copyWith(fontSize: 14, color: BloomColors.surface)),
            ]),
          ),
        ),
      );
}
