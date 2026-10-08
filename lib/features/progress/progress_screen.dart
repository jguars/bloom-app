import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/profile.dart';
import '../../data/weight.dart';
import '../../ui/bits.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../../ui/weight_chart.dart';
import 'journey.dart';
import 'weight_sheet.dart';

/// The upstairs hallway: your weight on one side, her journey on the other.
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
      _view = 0;
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

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider);
    final log = ref.watch(weightProvider);
    final units = ref.watch(unitsProvider);
    final next = journal.next;
    final nextIndex = next == null ? null : milestones.indexOf(next);
    final day = journal.dayNumber + 1;
    final subtitle = next == null
        ? 'Day $day · every flag reached!'
        : journal.dateOf(next).isAfter(journal.todayDate)
            ? 'Day $day of 60 · next flag on ${shortDate(journal.dateOf(next))}'
            : 'Day $day of 60 · next flag is in reach';
    final line = _reply ??
        (log.entries.isEmpty && _view == 0
            ? 'Hop on the scale? Only you see it.'
            : next == null
                ? 'We made it! Look at us!'
                : journal.totalMoves == 0
                    ? 'Our road starts here!'
                    : 'Look how far we’ve come!');
    return RoomFrame(
      asset: 'assets/scenes/hallway.jpg',
      // She daydreams under the next milestone's empty frame (or admires the full gallery).
      scene: CloverScene.progress,
      action: CloverAction.hallFor(nextIndex),
      room: Room.progress,
      head: Offset(nextIndex == null ? 512 : CloverScene.hallFrames[nextIndex].center.dx, 455),
      sceneOverlay: _Portraits(reached: milestones.where(journal.reached).length),
      line: line,
      bubbleLeft: 150,
      title: 'Progress',
      line2: 'Every flag we reach gets a portrait here!',
      subtitle: Text(subtitle, style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      children: [
        SegmentedSwitch(
          labels: const ['Your weight', 'Her journey'],
          index: _view,
          onChanged: (i) => setState(() {
            _view = i;
            _reply = null;
          }),
        ),
        const SizedBox(height: 16),
        SwipePanels(
          index: _view,
          count: 2,
          onChanged: (i) => setState(() {
            _view = i;
            _reply = null;
          }),
          child: AnimatedSwitcher(
            duration: BloomMotion.base,
            switchInCurve: BloomMotion.enter,
            switchOutCurve: BloomMotion.leave,
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            transitionBuilder: (c, a) => panelTransition(c, a),
            child: _view == 0
                ? KeyedSubtree(key: const ValueKey(0), child: _WeightView(log: log, units: units, journal: journal, onGoal: () => _openSheet(goalOnly: true), onLog: _openSheet))
                : KeyedSubtree(key: const ValueKey(1), child: JourneyView(journal: journal)),
          ),
        ),
        // Logging belongs to the weight panel only.
        if (_view == 0) ...[
          const SizedBox(height: 20),
          KeyedSubtree(
            key: _logKey,
            child: LedgeButton(label: 'Log weight', leading: const Icon(Icons.monitor_weight_outlined, color: BloomColors.onForest), onPressed: _openSheet),
          ),
        ],
      ],
    );
  }
}

class _WeightView extends StatelessWidget {
  const _WeightView({required this.log, required this.units, required this.journal, required this.onGoal, required this.onLog});
  final WeightLog log;
  final Units units;
  final Journal journal;
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
        Expanded(child: StatCard(value: '${journal.totalMoves} ${journal.totalMoves == 1 ? 'move' : 'moves'}', label: 'Done together')),
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

/// Her milestone portraits, hung in the hallway's frames: one per milestone reached.
class _Portraits extends StatelessWidget {
  const _Portraits({required this.reached});
  final int reached;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(builder: (context, box) {
          const scene = CloverScene.progress;
          final size = box.biggest;
          return Stack(children: [
            for (var i = 0; i < reached && i < CloverScene.hallFrames.length; i++)
              Positioned.fromRect(
                rect: Rect.fromPoints(scene.toScreen(CloverScene.hallFrames[i].topLeft, size), scene.toScreen(CloverScene.hallFrames[i].bottomRight, size)),
                child: Image.asset('assets/scenes/portrait-${i + 1}.webp', fit: BoxFit.cover),
              ),
          ]);
        }),
      );
}
