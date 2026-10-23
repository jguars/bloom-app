import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/clock.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/plan.dart';
import '../../data/profile.dart';
import '../../data/weight.dart';
import '../../ui/painted_icon.dart';
import '../../ui/bits.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../../ui/weight_chart.dart';
import '../profile/plan_report_screen.dart';
import '../profile/weekly_screen.dart';
import '../profile/weight_history_screen.dart';
import '../today/flow.dart';
import '../streak/streak_screens.dart' show StreakChip;
import 'journey.dart';
import 'panels.dart';
import 'weight_sheet.dart';

/// The stairs, where her portraits hang. Two jobs: the Journey (the next portrait, the week together, the reports)
/// and, for people who track it, Weight. Tap a frame to see its portrait up close.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _view = 0;
  String? _reply;
  final _logKey = GlobalKey();

  Future<void> _openSheet({bool goalOnly = false}) async {
    final before = ref.read(weightProvider).latest?.kg;
    final saved = await showBloomSheet<bool>(context, (c) => WeightSheet(goalOnly: goalOnly));
    if (saved != true || !mounted) return;
    final after = ref.read(weightProvider).latest?.kg;
    setState(() {
      _view = 1;
      _reply = goalOnly
          ? 'A goal! We’ll get there together.'
          : before == null
              ? 'Our first dot on the chart!'
              : after! < before - .05
                  ? 'Lighter than last time!'
                  : 'Noted! Every day’s a little different.';
    });
    SfxPlayer.instance.play(Sfx.chime);
    Feel.mediumImpact();
    final box = _logKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) FxLayer.burst(box.localToGlobal(box.size.center(Offset.zero)), count: 22, power: .6);
  }

  /// A tap on the hallway: the frame under it (with a little give) opens its portrait.
  void _tapScene(Offset at) {
    const scene = CloverScene.progress;
    final size = Size(MediaQuery.of(context).size.width, RoomFrame.sceneHeight(MediaQuery.of(context)));
    for (final (i, f) in CloverScene.hallFrames.indexed) {
      final r = Rect.fromCenter(center: scene.toScreen(f.center, size), width: f.width * scene.scaleIn(size) * 1.15, height: f.height * scene.scaleIn(size) * 1.15).inflate(10);
      if (r.contains(at)) {
        Feel.selectionClick();
        showPortrait(context, ref.read(journalProvider), i);
        return;
      }
    }
  }

  /// The stairwell's night painting, from late evening until dawn (as the living room's light, RoomLight).
  static bool _night(DateTime t) {
    final h = t.hour + t.minute / 60;
    return h >= 19.5 || h < 6;
  }

  void _setView(int i) => setState(() {
        _view = i;
        _reply = null;
      });

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider);
    final plan = ref.watch(planProvider);
    final log = ref.watch(weightProvider);
    final units = ref.watch(unitsProvider);
    final next = journal.next;
    final nextIndex = next == null ? null : milestones.indexOf(next);
    // Weight is optional: its panel shows once someone weighs in or sets a goal; until then Progress is one page.
    final tracksWeight = log.entries.isNotEmpty || log.goalKg != null;
    final view = tracksWeight ? _view : 0;
    final line = _reply ??
        (view == 1 && log.entries.isEmpty
            ? 'Hop on the scale? Only you see it.'
            : next == null
                ? 'We made it! Look at us!'
                : journal.totalMoves == 0
                    ? 'Our road starts here!'
                    : 'Look how far we’ve come!');
    final reports = GroupCard(children: [
      GroupRow(
        leading: const _RowIcon('calendar'),
        title: 'Weekly summary',
        caption: 'Your week with ${ref.watch(profileProvider.select((p) => p.catName))}',
        onTap: () => Navigator.of(context).push(bloomRoute(const WeeklyScreen())),
      ),
      GroupRow(
        leading: const _RowIcon('seedling'),
        title: 'Habit report',
        caption: 'Each habit, day by day',
        onTap: () => Navigator.of(context).push(bloomRoute(const PlanReportScreen())),
        last: !tracksWeight,
      ),
      if (tracksWeight)
        GroupRow(
          leading: const _RowIcon('scale'),
          title: 'Weight history',
          caption: log.entries.isEmpty ? 'No weigh-ins yet' : '${log.entries.length} ${log.entries.length == 1 ? 'log' : 'logs'} · latest ${units.weight(log.latest!.kg)}',
          onTap: () => Navigator.of(context).push(bloomRoute(const WeightHistoryScreen())),
          last: true,
        ),
    ]);
    final journey = Column(key: const ValueKey(0), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (next == null) KeepGoingCard(journal: journal) else NextPortraitCard(journal: journal, next: next, onOpen: (i) => showPortrait(context, journal, i)),
      const SizedBox(height: 14),
      TogetherView(journal: journal, plan: plan),
      const SizedBox(height: 20),
      const Eyebrow('Reports'),
      const SizedBox(height: 10),
      reports,
      if (!tracksWeight) ...[
        const SizedBox(height: 14),
        GroupCard(children: [
          GroupRow(
            leading: const _RowIcon('scale'),
            title: 'Track your weight',
            caption: 'Optional · only you see it',
            onTap: _openSheet,
            last: true,
          ),
        ]),
      ],
    ]);
    final weight = Column(key: const ValueKey(1), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _WeightView(log: log, units: units, onGoal: () => _openSheet(goalOnly: true), onLog: _openSheet),
      const SizedBox(height: 16),
      KeyedSubtree(
        key: _logKey,
        child: LedgeButton(label: 'Log today’s weight', leading: const Icon(Icons.monitor_weight_outlined, color: BloomColors.onForest), onPressed: _openSheet),
      ),
      const SizedBox(height: 14),
      GroupCard(children: [
        GroupRow(
          leading: const _RowIcon('scale'),
          title: 'Weight history',
          caption: log.entries.isEmpty ? 'No weigh-ins yet' : '${log.entries.length} ${log.entries.length == 1 ? 'log' : 'logs'}',
          onTap: () => Navigator.of(context).push(bloomRoute(const WeightHistoryScreen())),
          last: true,
        ),
      ]),
    ]);
    return RoomFrame(
      asset: 'assets/scenes/stairs-day.jpg',
      // She daydreams under the next milestone's empty frame (or admires the full gallery).
      scene: CloverScene.progress,
      action: CloverAction.hallFor(nextIndex),
      room: Room.progress,
      head: CloverScene.stairHead(nextIndex),
      night: _night(ref.watch(clockProvider)()),
      sceneOverlay: _Portraits(reached: milestones.where(journal.reached).length),
      onSceneTap: _tapScene,
      line: line,
      bubbleLeft: 150,
      title: 'Progress',
      // The streak sits on the title row, as the Habits' photo check and the Shop's Plus do.
      titleTrailing: const StreakChip(),
      line2: 'Every milestone we reach gets a portrait here!',
      subtitle: Text('Every move together climbs the stairs.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      panel: view,
      // Two jobs, two panels: the journey (first) and, for people who track it, weight.
      pinned: tracksWeight ? [SegmentedSwitch(labels: const ['Journey', 'Weight'], index: view, onChanged: _setView)] : const [],
      children: [
        if (!tracksWeight)
          journey
        else
          SwipePanels(
            index: view,
            count: 2,
            onChanged: _setView,
            child: AnimatedSwitcher(
              duration: BloomMotion.base,
              switchInCurve: BloomMotion.enter,
              switchOutCurve: BloomMotion.leave,
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              transitionBuilder: (c, a) => panelTransition(c, a),
              child: view == 0 ? journey : weight,
            ),
          ),
      ],
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  /// A painted icon's name (assets/icons).
  final String icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
        child: Center(child: PaintedIcon(icon, size: 30)),
      );
}

class _WeightView extends StatelessWidget {
  const _WeightView({required this.log, required this.units, required this.onGoal, required this.onLog});
  final WeightLog log;
  final Units units;
  final VoidCallback onGoal, onLog;

  @override
  Widget build(BuildContext context) {
    final latest = log.latest;
    final week = log.weekChange;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (latest == null)
        BloomCard(
          onTap: onLog,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('Your weight'),
            const SizedBox(height: 6),
            Text('No weigh-ins yet', style: BloomText.headline),
            const SizedBox(height: 4),
            Text('Log your weight and Clover will draw your line next to a gentle plan. It never changes her shape.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
          ]),
        )
      else
        BloomCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Your weight'),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: units.show(latest.kg)),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(v.toStringAsFixed(1), style: BloomText.display.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                  const SizedBox(width: 4),
                  Text(units.name, style: BloomText.caption),
                ]),
              ]),
              const Spacer(),
              if (log.entries.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BloomTag(
                    text: '${units.change(log.change)} since ${shortDate(log.first!.at)}',
                    icon: log.change < 0 ? Icons.south_rounded : null,
                    tone: log.change < 0 ? TagTone.done : TagTone.neutral,
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            WeightChart(log: log, units: units, now: DateTime.now()),
            const SizedBox(height: 8),
            Row(children: [
              const _Legend(dashed: false, label: 'You'),
              const SizedBox(width: 16),
              const _Legend(dashed: true, label: 'Plan'),
              const Spacer(),
              GestureDetector(
                onTap: onGoal,
                child: Row(children: [
                  Container(width: 14, height: 2, color: BloomColors.mustard),
                  const SizedBox(width: 6),
                  Text(log.goalKg == null ? 'Set a goal' : 'Goal ${units.weight(log.goalKg!)}', style: BloomText.caption.copyWith(color: BloomColors.ink, decoration: TextDecoration.underline, decorationColor: BloomColors.line)),
                ]),
              ),
            ]),
          ]),
        ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: StatCard(value: week == null ? '—' : units.change(week), label: 'This week')),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onGoal,
            child: StatCard(
              value: log.goalKg == null ? 'Set one' : units.weight(log.goalKg!),
              label: log.goalKg == null || latest == null
                  ? 'Goal'
                  : latest.kg - log.goalKg! <= 0.05
                      ? 'Goal · reached!'
                      : 'Goal · ${units.weight(latest.kg - log.goalKg!)} to go',
            ),
          ),
        ),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.dashed, required this.label});
  final bool dashed;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 22,
          child: dashed
              ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(3, (_) => Container(width: 5, height: 2.5, color: BloomColors.skyDeep)))
              : Container(height: 3.5, decoration: BoxDecoration(color: BloomColors.forest, borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(width: 6),
        Text(label, style: BloomText.caption),
      ]);
}

/// Her milestone portraits, hung in the hallway, a little larger than the painted frames and each in
/// its own wooden frame over them. Reached ones are in colour; the rest are grey (the next one
/// with a soft mustard glow, to say it's waiting and can be tapped; later ones fainter).
class _Portraits extends StatefulWidget {
  const _Portraits({required this.reached});
  final int reached;

  @override
  State<_Portraits> createState() => _PortraitsState();
}

class _PortraitsState extends State<_Portraits> with SingleTickerProviderStateMixin {
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  static const _grey = ColorFilter.mode(Color(0xFFB8B0A0), BlendMode.saturation);
  static const _wood = Color(0xFFA9683A);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(builder: (context, box) {
          const scene = CloverScene.progress;
          final size = box.biggest;
          final k = scene.scaleIn(size);
          final n = widget.reached;
          final reduce = MediaQuery.of(context).disableAnimations;
          return Stack(children: [
            for (final (i, f) in CloverScene.hallFrames.indexed)
              Positioned.fromRect(
                // 15% larger than the painted picture, plus a wooden border that covers the painted frame.
                rect: Rect.fromCenter(center: scene.toScreen(f.center, size), width: f.width * k * 1.15, height: f.height * k * 1.15).inflate(4 * k),
                child: Opacity(
                  opacity: i < n ? 1 : (i == n ? .9 : .7),
                  child: Container(
                    padding: EdgeInsets.all(5 * k),
                    decoration: BoxDecoration(
                      color: _wood,
                      borderRadius: BorderRadius.circular(3 * k),
                      boxShadow: [BoxShadow(color: const Color(0x40403A1E), blurRadius: 6 * k, offset: Offset(0, 3 * k))],
                    ),
                    child: i < n
                        ? Image.asset('assets/scenes/portrait-${i + 1}.webp', fit: BoxFit.cover)
                        : ColorFiltered(colorFilter: _grey, child: Image.asset('assets/scenes/portrait-${i + 1}.webp', fit: BoxFit.cover)),
                  ),
                ),
              ),
            if (n < CloverScene.hallFrames.length)
              Positioned.fromRect(
                rect: Rect.fromCenter(center: scene.toScreen(CloverScene.hallFrames[n].center, size), width: CloverScene.hallFrames[n].width * k * 1.15, height: CloverScene.hallFrames[n].height * k * 1.15)
                    .inflate(4 * k + 3),
                child: AnimatedBuilder(
                  animation: _glow,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: BloomColors.mustard.withValues(alpha: reduce ? .8 : .45 + .5 * _glow.value), width: 3),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      );
}
