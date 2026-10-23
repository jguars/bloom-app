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
import '../../ui/painted_icon.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../../ui/title_pill.dart';
import '../today/flow.dart';
import '../food/food_check_screen.dart';
import 'rule_sheet.dart';
import '../../ui/rule_icon.dart';

/// The balcony garden: your habits, in one list: the ones to do, then the ones to avoid. Each section keeps
/// what's up next on top (the most frequent first); a logged habit sinks to the bottom, and a repeatable one
/// floats back up after its rest. Up top, today's target: keep three.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
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
      title: 'Habits',
      line2: 'Small swaps add up. You’ve got this.',
      titleTrailing: const _PhotoCheckButton(),
      subtitle: Text('Small daily choices that add up. Keep $kDailyHabits a day.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      // One list (no sub-panels): the room tucks away as it scrolls, the title docks.
      pinned: const [],
      children: [
        if (plan.rules.isNotEmpty) ...[_TodayTarget(plan: plan), const SizedBox(height: 18)],
        _Panel(kind: PlanKind.more, plan: plan, now: now),
        const SizedBox(height: 22),
        _Panel(kind: PlanKind.skip, plan: plan, now: now),
      ],
    );
  }
}

/// One list. Rows sit in fixed slots so that when one is logged it can glide down to its new place
/// (after a beat, so the tick lands first).
class _Panel extends StatefulWidget {
  const _Panel({required this.kind, required this.plan, required this.now});
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
      label: more ? 'Add a habit to do' : 'Add one to avoid',
      variant: LedgeVariant.secondary,
      leading: const Icon(Icons.add_rounded, color: BloomColors.ink),
      onPressed: () => showBloomSheet<void>(context, (c) => RuleSheet(kind: widget.kind)),
    );
    if (rules.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(more ? 'TO DO' : 'TO AVOID', style: BloomText.label),
        const SizedBox(height: 8),
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
          header(at.allDone ? (more ? 'TO DO · ALL DONE' : 'TO AVOID · ALL KEPT') : (more ? 'TO DO' : 'TO AVOID'), 0),
          header(more ? 'DONE TODAY' : 'SAID NO TODAY', at.second),
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

  /// A repeatable rule: one more log (a log is final: no undo).
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
    messenger.showSnackBar(_snack(r.kind == PlanKind.more ? '${r.title} · $n today' : 'Said no · ${r.title.toLowerCase()} · $n today'));
  }

  /// A once-a-day rule: a tick. Once ticked it stays ticked for the day.
  void _tick() {
    if (!ref.read(planProvider.notifier).keep(widget.rule.id)) return;
    Feel.lightImpact();
    SfxPlayer.instance.play(Sfx.check);
    _fly(kPawsPerRule);
    widget.onLogged();
  }

  SnackBar _snack(String text) => SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        persist: false,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        backgroundColor: BloomColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd)),
        content: Text(text, style: BloomText.body.copyWith(color: BloomColors.surface), maxLines: 1, overflow: TextOverflow.ellipsis),
      );

  String _meta() {
    final r = widget.rule, n = widget.count, more = r.kind == PlanKind.more;
    if (!r.repeats) return n > 0 ? (more ? 'Done today · +$kPawsPerRule paws' : 'Kept today · +$kPawsPerRule paws') : (more ? 'Once a day' : 'Tick when you’ve said no today');
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
    final (tint, deep) = more ? (BloomColors.forestSoft, BloomColors.forest) : (BloomColors.mustardSoft, BloomColors.forest);
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
              child: Center(child: RuleIcon(r.icon, size: 36, color: deep)),
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
    const deep = BloomColors.forest;
    final fill = !due ? BloomColors.surface : BloomColors.forest;
    final fg = due ? BloomColors.onForest : deep;
    final ledge = due ? BloomColors.forestPress : BloomColors.line;
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
    final fill = on ? BloomColors.forest : BloomColors.surface;
    final fg = on ? BloomColors.onForest : BloomColors.lineStrong;
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
              border: Border.all(color: on ? BloomColors.forest : BloomColors.lineStrong, width: 2),
              boxShadow: [BoxShadow(color: on ? BloomColors.forestPress : BloomColors.line, offset: const Offset(0, 3))],
            ),
            // A habit to avoid is kept by saying no: a check, like any other win.
            child: Icon(Icons.check_rounded, color: fg, size: 22, weight: 700),
          ),
        ),
      ),
    );
  }
}

/// "Snap a plate": the shared title pill with a camera, opposite the Habits title. Opens the photo check.
class _PhotoCheckButton extends StatelessWidget {
  const _PhotoCheckButton();

  @override
  Widget build(BuildContext context) => TitlePill(
        icon: const PaintedIcon('camera', size: TitlePill.artSize),
        label: 'Snap a plate',
        semantics: 'Is this on my plan? Check a photo',
        onTap: () => Navigator.of(context).push(bloomRoute(const FoodCheckScreen())),
      );
}

/// How many habits make a kept day.
const kDailyHabits = 3;

/// Today's target, above the list: a ring of the habits kept today (each habit counts once, however many times
/// it's logged) toward [kDailyHabits].
class _TodayTarget extends StatelessWidget {
  const _TodayTarget({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final kept = plan.rules.where((r) => plan.count(r.id) > 0).length;
    final goal = plan.rules.length < kDailyHabits ? plan.rules.length : kDailyHabits;
    final done = kept >= goal;
    final left = goal - kept;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(color: done ? BloomColors.forestSoft : BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
      child: Row(children: [
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: goal == 0 ? 0 : (kept / goal).clamp(0.0, 1.0)),
              duration: BloomMotion.slow,
              curve: BloomMotion.spring,
              builder: (context, v, _) => SizedBox.expand(child: CircularProgressIndicator(value: v, strokeWidth: 7, strokeCap: StrokeCap.round, color: BloomColors.forest, backgroundColor: BloomColors.line)),
            ),
            Text('$kept/$goal', style: BloomText.headline.copyWith(fontSize: 15, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(done ? 'Today’s habits kept!' : '$kept of $goal kept today', style: BloomText.headline.copyWith(fontSize: 17)),
            const SizedBox(height: 2),
            Text(
              done ? 'Today counts as an active day · +${plan.pawsToday} paws' : (left == 1 ? 'One more makes today an active day' : '$left more make today an active day'),
              style: BloomText.caption,
            ),
          ]),
        ),
      ]),
    );
  }
}
