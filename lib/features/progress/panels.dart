import 'package:flutter/material.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/plan.dart';
import '../../ui/bits.dart';
import '../../ui/weight_chart.dart';
import 'journey.dart';

/// Which list a logged rule id belongs to: the plan's own say, or (for rules since removed) its id.
bool _isDont(String id, Plan plan) =>
    plan.rules.where((r) => r.id == id).firstOrNull?.kind == PlanKind.skip || id.startsWith('skip-') || RegExp(r'^s\d+$').hasMatch(id);

/// The first panel: the week the two of them had (or, with a day tapped, that day), and the
/// portrait they're working toward.
class TogetherView extends StatefulWidget {
  const TogetherView({super.key, required this.journal, required this.plan, required this.onNext});
  final Journal journal;
  final Plan plan;
  final VoidCallback onNext;

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
    final TogetherView(:journal, :plan, :onNext) = widget;
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
    final next = journal.next;
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
          Row(children: [
            Expanded(child: _Count(value: '$moves', label: moves == 1 ? 'move done' : 'moves done')),
            const SizedBox(width: 8),
            Expanded(
              child: picked == null
                  ? _Count(value: '$active of 7', label: 'days active')
                  : _Count(value: '${(seconds / 60).round()} min', label: 'moved together'),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Count(value: '$dos', label: 'Do’s logged', color: BloomColors.forest)),
            const SizedBox(width: 8),
            Expanded(child: _Count(value: '$donts', label: donts == 1 ? 'time said no' : 'times said no', color: BloomColors.clayDeep)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      if (next == null) KeepGoingCard(journal: journal) else NextPortraitCard(journal: journal, next: next, onTap: onNext),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.touch_app_outlined, size: 16, color: BloomColors.inkMuted),
        const SizedBox(width: 6),
        Flexible(child: Text('Tap a frame in the hallway to see her portrait', style: BloomText.caption, textAlign: TextAlign.center)),
      ]),
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
  const _Count({required this.value, required this.label, this.color = BloomColors.ink});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(color: BloomColors.paper, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: BloomText.title.copyWith(fontSize: 22, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
          Text(label, style: BloomText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

/// The second panel: each plan rule over the last seven days, the most logged first. Each list
/// shows its top three until expanded.
class HabitsView extends StatefulWidget {
  const HabitsView({super.key, required this.journal, required this.plan});
  final Journal journal;
  final Plan plan;

  @override
  State<HabitsView> createState() => _HabitsViewState();
}

class _HabitsViewState extends State<HabitsView> {
  static const _top = 3;
  final _open = <PlanKind>{};

  @override
  Widget build(BuildContext context) {
    final HabitsView(:journal, :plan) = widget;
    final days = journal.lastDays();
    List<int> week(PlanRule r) => [for (final d in days) journal.on(d).count(r.id)];
    if (plan.rules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
        child: Text('Add a few Do’s and Don’ts on the balcony and they’ll show up here, day by day.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      );
    }
    // The rule kept on the most days (then the most often).
    (PlanRule, int)? best;
    var bestSum = 0;
    for (final r in plan.rules) {
      final w = week(r);
      final n = w.where((c) => c > 0).length, sum = w.fold(0, (a, b) => a + b);
      if (n > 0 && (best == null || n > best.$2 || (n == best.$2 && sum > bestSum))) {
        best = (r, n);
        bestSum = sum;
      }
    }
    Widget list(PlanKind k, String title) {
      final weeks = {for (final r in plan.of(k)) r.id: week(r)};
      int sum(String id) => weeks[id]!.fold(0, (a, b) => a + b);
      int kept(String id) => weeks[id]!.where((c) => c > 0).length;
      final rules = [
        for (final (_, r) in (plan.of(k).indexed.toList()
          ..sort((a, b) {
            final d = sum(b.$2.id) - sum(a.$2.id);
            if (d != 0) return d;
            final e = kept(b.$2.id) - kept(a.$2.id);
            return e != 0 ? e : a.$1 - b.$1;
          })))
          r,
      ];
      if (rules.isEmpty) return const SizedBox.shrink();
      final open = _open.contains(k);
      final shown = open ? rules : rules.take(_top).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(2, 6, 0, 8), child: Eyebrow(title)),
        AnimatedSize(
          duration: BloomMotion.slow,
          curve: BloomMotion.enter,
          alignment: Alignment.topCenter,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final r in shown) ...[
              _HabitRow(key: ValueKey(r.id), rule: r, week: weeks[r.id]!),
              const SizedBox(height: 10),
            ],
          ]),
        ),
        if (rules.length > _top) ...[
          _ShowMore(
            open: open,
            label: open ? 'Show top $_top' : 'Show all ${rules.length}',
            onTap: () {
              Feel.selectionClick();
              setState(() => open ? _open.remove(k) : _open.add(k));
            },
          ),
          const SizedBox(height: 10),
        ],
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (best case (final r, final n)) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: BloomColors.mustardSoft, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
          child: Row(children: [
            const Icon(Icons.emoji_events_outlined, color: BloomColors.mustardPress, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MOST KEPT THIS WEEK', style: BloomText.label.copyWith(color: BloomColors.mustardPress)),
                Text('${r.title} · $n of 7 days', style: BloomText.headline.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      list(PlanKind.more, 'Do’s · last 7 days'),
      list(PlanKind.skip, 'Don’ts · last 7 days'),
    ]);
  }
}

class _ShowMore extends StatelessWidget {
  const _ShowMore({required this.open, required this.label, required this.onTap});
  final bool open;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        expanded: open,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(BloomSpace.rMd), border: Border.all(color: BloomColors.line, width: 2)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: BloomText.button.copyWith(fontSize: 15, color: BloomColors.ink)),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: open ? .5 : 0,
                duration: BloomMotion.base,
                child: const Icon(Icons.expand_more_rounded, color: BloomColors.ink, size: 22),
              ),
            ]),
          ),
        ),
      );
}

/// One rule's week: a bar per day, filled by how much of the daily goal was met (a whole bar for a
/// once-a-day rule kept); today, still going, on the right with a mustard ring.
class _HabitRow extends StatelessWidget {
  const _HabitRow({super.key, required this.rule, required this.week});
  final PlanRule rule;
  final List<int> week;

  @override
  Widget build(BuildContext context) {
    final more = rule.kind == PlanKind.more;
    final (tint, deep, soft) = more ? (BloomColors.forestSoft, BloomColors.forest, BloomColors.sage) : (BloomColors.claySoft, BloomColors.clayDeep, BloomColors.blush);
    final sum = week.fold(0, (a, b) => a + b);
    final kept = week.where((c) => c > 0).length;
    final met = week.where((c) => c >= rule.goal).length;
    // The count sits by the title; the line under it says how the days went.
    final meta = !rule.repeats ? '$kept of 7 days' : (more ? 'Goal met $met ${met == 1 ? 'day' : 'days'} · on $kept' : 'Said no on $kept of 7 days');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
      decoration: cardDecoration(radius: BloomSpace.rMd),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
          child: Icon(iconFor(rule.icon), color: deep, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(rule.title, style: BloomText.headline.copyWith(fontSize: 15, height: 20 / 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('$sum×', style: BloomText.caption.copyWith(color: sum > 0 ? deep : BloomColors.inkMuted)),
            ]),
            Text(meta, style: BloomText.caption.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            SizedBox(
              height: 26,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, c) in week.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: BloomColors.paper,
                        borderRadius: BorderRadius.circular(5),
                        border: i == week.length - 1 ? Border.all(color: BloomColors.mustard, width: 1.5) : null,
                      ),
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (c / rule.goal).clamp(0.0, 1.0)),
                        duration: Duration(milliseconds: 500 + 40 * i),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => FractionallySizedBox(
                          heightFactor: v,
                          widthFactor: 1,
                          child: DecoratedBox(decoration: BoxDecoration(color: c >= rule.goal ? deep : soft, borderRadius: BorderRadius.circular(4))),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
