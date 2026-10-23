import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/plan.dart';
import '../../ui/bits.dart';
import '../../ui/weight_chart.dart';
import 'week_stats.dart';
import '../../ui/rule_icon.dart';

/// Each habit, and which of the last seven days it was kept (opened from Progress).
class PlanReportScreen extends ConsumerWidget {
  const PlanReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider);
    final plan = ref.watch(planProvider);
    final w = WeekStats(journal);
    final t = journal.todayDate;
    final labels = [for (var i = 6; i >= 0; i--) weekdays[t.subtract(Duration(days: i)).weekday - 1][0]];
    Widget section(PlanKind k, String name) {
      final rules = plan.of(k);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Eyebrow(name),
        const SizedBox(height: 10),
        if (rules.isEmpty) Text('None here yet.', style: BloomText.bodyMuted),
        for (final r in rules) ...[
          _RuleWeek(rule: r, kept: w.keptDays(r.id), labels: labels),
          const SizedBox(height: 10),
        ],
      ]);
    }

    return SubPage(
      from: 'Progress',
      title: 'Habit report',
      children: [
        Text('The last 7 days, ending today.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
        const SizedBox(height: 16),
        section(PlanKind.more, 'To do'),
        const SizedBox(height: 8),
        section(PlanKind.skip, 'To avoid'),
      ],
    );
  }
}

class _RuleWeek extends StatelessWidget {
  const _RuleWeek({required this.rule, required this.kept, required this.labels});
  final PlanRule rule;
  final List<bool> kept;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final more = rule.kind == PlanKind.more;
    final n = kept.where((k) => k).length;
    return BloomCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: more ? BloomColors.forestSoft : BloomColors.mustardSoft, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
            child: Center(child: RuleIcon(rule.icon, size: 30, color: BloomColors.forest)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(rule.title, style: BloomText.headline.copyWith(fontSize: 16))),
          Text('$n of 7', style: BloomText.caption.copyWith(color: BloomColors.ink)),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 7; i++)
            Column(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + 50 * i),
                curve: Interval((50 * i) / (300 + 50 * i), 1, curve: Curves.easeOutBack),
                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: kept[i] ? BloomColors.forest : BloomColors.paperSunk, shape: BoxShape.circle),
                  child: kept[i] ? const Icon(Icons.check_rounded, size: 16, color: BloomColors.surface) : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: BloomText.label.copyWith(fontSize: 11)),
            ]),
        ]),
      ]),
    );
  }
}
