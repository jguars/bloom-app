import 'package:flutter/material.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/plan.dart';
import '../../ui/bits.dart';
import '../../ui/weight_chart.dart';

/// Which list a logged rule id belongs to: the plan's own say, or (for rules since removed) its id.
bool _isDont(String id, Plan plan) =>
    plan.rules.where((r) => r.id == id).firstOrNull?.kind == PlanKind.skip || id.startsWith('skip-') || RegExp(r'^s\d+$').hasMatch(id);

/// The week the two of them had (or, with a day tapped, that day): the week strip and three numbers.
class TogetherView extends StatefulWidget {
  const TogetherView({super.key, required this.journal, required this.plan});
  final Journal journal;
  final Plan plan;

  @override
  State<TogetherView> createState() => _TogetherViewState();
}

class _TogetherViewState extends State<TogetherView> {
  int? _day;

  void _pick(int i) {
    Feel.selectionClick();
    setState(() => _day = _day == i ? null : i);
  }

  @override
  Widget build(BuildContext context) {
    final TogetherView(:journal, :plan) = widget;
    final days = journal.lastDays();
    final all = [for (final d in days) journal.on(d)];
    final picked = _day;
    final logs = picked == null ? all : [all[picked]];
    var moves = 0, active = 0, dos = 0, donts = 0, seconds = 0;
    for (final l in logs) {
      final ids = {...l.counts.keys, ...l.kept};
      var logged = 0;
      for (final id in ids) {
        final n = l.count(id);
        logged += n;
        if (_isDont(id, plan)) {
          donts += n;
        } else {
          dos += n;
        }
      }
      moves += l.moves;
      seconds += l.seconds;
      if (l.moves > 0 || logged > 0) active++;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BloomCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 26,
            child: Row(children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: BloomMotion.fast,
                  layoutBuilder: (c, p) => Stack(alignment: Alignment.centerLeft, children: [...p, ?c]),
                  child: Eyebrow(
                    picked == null ? 'This week together' : (picked == days.length - 1 ? 'Today, ${shortDate(days[picked])}' : '${weekdays[days[picked].weekday - 1]}, ${shortDate(days[picked])}'),
                    key: ValueKey(picked),
                  ),
                ),
              ),
              if (picked == null)
                Text('${shortDate(days.first)} – ${shortDate(days.last)}', style: BloomText.caption)
              else
                Semantics(
                  button: true,
                  label: 'Back to the whole week',
                  child: GestureDetector(
                    onTap: () => _pick(picked),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
                      decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Whole week', style: BloomText.caption.copyWith(color: BloomColors.ink)),
                        const SizedBox(width: 2),
                        const Icon(Icons.close_rounded, size: 15, color: BloomColors.ink),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            for (final (i, d) in days.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: picked == i,
                  label: '${weekdays[d.weekday - 1]} ${shortDate(d)}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pick(i),
                    child: _DayCell(day: d, log: all[i], today: i == days.length - 1, selected: picked == i),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          // Three numbers, all wins (saying no to a habit counts as keeping it).
          Row(children: [
            Expanded(child: _Count(value: '$moves', label: moves == 1 ? 'move' : 'moves')),
            const SizedBox(width: 8),
            Expanded(child: _Count(value: '${dos + donts}', label: 'habits kept')),
            const SizedBox(width: 8),
            Expanded(
              child: picked == null
                  ? _Count(value: '$active/7', label: 'active days')
                  : _Count(value: '${(seconds / 60).round()} min', label: 'moving'),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

/// A day in the week strip: deep green with a move done, sage with only plan logs, sunk when
/// quiet; today has a mustard ring.
class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.log, required this.today, required this.selected});
  final DateTime day;
  final DayLog log;
  final bool today, selected;

  @override
  Widget build(BuildContext context) {
    final logged = log.counts.isNotEmpty || log.kept.isNotEmpty;
    final fill = log.moves > 0 ? BloomColors.forest : (logged ? BloomColors.sage : BloomColors.paperSunk);
    // The picked day lifts, with an ink ring.
    return Column(children: [
      AnimatedSlide(
        duration: BloomMotion.base,
        curve: BloomMotion.spring,
        offset: Offset(0, selected ? -.12 : 0),
        child: AnimatedContainer(
          duration: BloomMotion.base,
          height: 28,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: today ? Border.all(color: BloomColors.mustard, width: 2) : null,
            boxShadow: selected ? const [BoxShadow(color: BloomColors.surface, spreadRadius: 2), BoxShadow(color: BloomColors.ink, spreadRadius: 4)] : const [],
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        weekdays[day.weekday - 1][0],
        style: BloomText.caption.copyWith(fontSize: 12, color: today || selected ? BloomColors.ink : BloomColors.inkMuted, fontWeight: selected ? FontWeight.w900 : null),
      ),
    ]);
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(color: BloomColors.paper, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: BloomText.title.copyWith(fontSize: 22, color: BloomColors.forest, fontFeatures: const [FontFeature.tabularFigures()])),
          Text(label, style: BloomText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}
