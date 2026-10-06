import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/profile.dart';
import '../../data/today.dart';
import '../../data/weight.dart';
import '../../ui/bits.dart';
import '../../ui/clover_rive.dart';
import '../../ui/ledge_button.dart';
import '../../ui/speech_bubble.dart';
import '../../ui/weight_chart.dart';
import 'week_stats.dart';

class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider);
    final log = ref.watch(weightProvider);
    final units = ref.watch(unitsProvider);
    final cat = ref.watch(profileProvider.select((p) => p.catName));
    final w = WeekStats(journal);
    final kept = w.planKept;
    final best = w.bestDay;
    final startW = log.at(w.days.first.subtract(const Duration(seconds: 1)));
    final endW = log.at(w.days.last.add(const Duration(days: 1)));
    final change = (startW != null && endW != null && !identical(startW, endW)) ? units.change(endW.kg - startW.kg) : '—';
    final todayIndex = journal.todayDate.weekday - 1;
    final line = w.moves == 0
        ? 'A fresh week! Shall we start with one move?'
        : best != null && w.logs[best].moves >= kDailyGoal
            ? '${weekdays[best]} was our best day! Let’s do another like it.'
            : 'We moved on ${w.activeDays} ${w.activeDays == 1 ? 'day' : 'days'}. One more next week?';

    return SubPage(
      from: 'Profile',
      title: 'Your week with $cat',
      bottom: LedgeButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
      children: [
        Text('${shortDate(w.days.first)} – ${shortDate(w.days.last)}', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: [
            StatCard(value: '${w.moves} of ${7 * kDailyGoal}', label: 'Moves together'),
            StatCard(value: '${w.minutes} min', label: 'Time moving'),
            StatCard(value: kept == null ? '—' : '${(kept * 100).round()}%', label: 'Plan kept'),
            StatCard(value: change, label: 'Weight change'),
            StatCard(value: '${w.checkIns} of 7', label: 'Check-ins'),
            StatCard(value: w.urges == 0 ? '—' : '${w.rodeOut} of ${w.urges}', label: 'Cravings ridden out'),
          ],
        ),
        const SizedBox(height: 12),
        BloomCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Eyebrow('Moves each day'),
            const SizedBox(height: 14),
            SizedBox(
              height: 136,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < 7; i++) Expanded(child: _Bar(moves: w.logs[i].moves, label: weekdays[i][0], today: i == todayIndex, best: i == best, delay: 60 * i)),
              ]),
            ),
            const SizedBox(height: 10),
            Text(best == null ? 'No moves yet this week.' : 'Best day: ${weekdays[best]}, ${w.logs[best].moves} ${w.logs[best].moves == 1 ? 'move' : 'moves'}.', style: BloomText.caption.copyWith(fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(width: 96, height: 112, child: LiveClover(action: w.moves > 0 ? CloverAction.cheer : CloverAction.rest)),
          const SizedBox(width: 8),
          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 30), child: SpeechBubble(text: line))),
        ]),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.moves, required this.label, required this.today, required this.best, required this.delay});
  final int moves, delay;
  final String label;
  final bool today, best;

  @override
  Widget build(BuildContext context) {
    final frac = (moves / kDailyGoal).clamp(0.0, 1.0);
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (moves > 0) Text('$moves', style: BloomText.caption.copyWith(color: BloomColors.ink)),
      const SizedBox(height: 4),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 700 + delay),
        curve: Interval(delay / (700 + delay), 1, curve: Curves.easeOutBack),
        builder: (context, t, _) => Container(
          width: 22,
          height: 6 + 70 * frac * t,
          decoration: BoxDecoration(
            color: moves == 0 ? BloomColors.paperSunk : (best ? BloomColors.mustard : BloomColors.forest),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: today ? const BoxDecoration(color: BloomColors.forestSoft, shape: BoxShape.circle) : null,
        child: Text(label, style: BloomText.label.copyWith(color: today ? BloomColors.forest : BloomColors.inkMuted)),
      ),
    ]);
  }
}
