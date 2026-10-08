import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../ui/bits.dart';
import '../../ui/weight_chart.dart';

/// The five flags on one track: reached ones ticked, the next one glowing.
class JourneyTrack extends StatelessWidget {
  const JourneyTrack({super.key, required this.journal});
  final Journal journal;

  @override
  Widget build(BuildContext context) {
    final next = journal.next;
    return LayoutBuilder(builder: (context, c) {
      final step = c.maxWidth / milestones.length;
      return SizedBox(
        height: 74,
        child: Stack(children: [
          Positioned(
            left: step / 2,
            right: step / 2,
            top: 13,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(children: [
                  const Positioned.fill(child: ColoredBox(color: BloomColors.paperSunk)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: journal.trackFill),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FractionallySizedBox(widthFactor: v, child: const ColoredBox(color: BloomColors.forest)),
                  ),
                ]),
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < milestones.length; i++)
              SizedBox(
                width: step,
                child: _Node(
                  m: milestones[i],
                  state: journal.reached(milestones[i]) ? _S.done : (milestones[i] == next ? _S.now : _S.later),
                  date: i == 0 ? shortDate(journal.startDate) : shortDate(journal.dateOf(milestones[i])),
                  delay: Duration(milliseconds: 150 + 120 * i),
                ),
              ),
          ]),
        ]),
      );
    });
  }
}

enum _S { done, now, later }

class _Node extends StatelessWidget {
  const _Node({required this.m, required this.state, required this.date, required this.delay});
  final Milestone m;
  final _S state;
  final String date;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final dot = switch (state) {
      _S.done => Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: BloomColors.forest, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: BloomColors.onForest, size: 18),
        ),
      _S.now => const _Pulse(),
      _S.later => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle, border: Border.all(color: BloomColors.line, width: 2)),
        ),
    };
    return Column(children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: BloomMotion.slow + delay,
        curve: Interval(delay.inMilliseconds / (BloomMotion.slow + delay).inMilliseconds, 1, curve: BloomMotion.pop),
        builder: (context, s, child) => Transform.scale(scale: s, child: child),
        child: dot,
      ),
      const SizedBox(height: 6),
      Text(m.tag, style: BloomText.label.copyWith(color: state == _S.later ? BloomColors.inkMuted : BloomColors.ink)),
      Text(date, style: BloomText.caption.copyWith(fontSize: 12)),
    ]);
  }
}

/// The next flag: a mustard ring that breathes.
class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        height: 32,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Transform.scale(
              scale: 1 + .5 * _c.value,
              child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: BloomColors.mustard.withValues(alpha: .35 * (1 - _c.value)))),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: BloomColors.mustardSoft, shape: BoxShape.circle, border: Border.all(color: BloomColors.mustard, width: 3)),
            ),
          ]),
        ),
      );
}

/// "Her journey": Clover now, then each flag with the shape she'll have.
class JourneyView extends StatelessWidget {
  const JourneyView({super.key, required this.journal});
  final Journal journal;

  @override
  Widget build(BuildContext context) {
    final next = journal.next;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BloomCard(
        child: Row(children: [
          // Her portrait from the last milestone reached (the same one hanging in the hallway).
          ClipRRect(
            borderRadius: BorderRadius.circular(BloomSpace.rMd),
            child: Image.asset(
              'assets/scenes/portrait-${milestones.where(journal.reached).length.clamp(1, milestones.length)}.webp',
              width: 96,
              height: 115,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Clover now'),
              const SizedBox(height: 2),
              Text('${(100 - journal.bodyMass).round()}% of the way', style: BloomText.headline),
              const SizedBox(height: 4),
              Text('Her shape follows your moves together, never the scale.', style: BloomText.caption.copyWith(fontSize: 14, height: 20 / 14)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      BloomCard(child: JourneyTrack(journal: journal)),
      const SizedBox(height: 16),
      for (final m in milestones) ...[
        _FlagRow(m: m, journal: journal, isNext: m == next),
        const SizedBox(height: 12),
      ],
      Text('Flags come with effort, not the calendar. A slow week never takes one away.', style: BloomText.caption.copyWith(fontSize: 14), textAlign: TextAlign.center),
    ]);
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({required this.m, required this.journal, required this.isNext});
  final Milestone m;
  final Journal journal;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final reached = journal.reached(m);
    final remaining = (m.effort - journal.effort).clamp(0, 999);
    final moves = remaining.ceil();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(radius: BloomSpace.rMd).copyWith(
        border: isNext ? Border.all(color: BloomColors.mustard, width: 2) : null,
      ),
      child: Row(children: [
        // Her portrait for this milestone (the same one that hangs in the hallway once it's reached);
        // flags beyond the next one are faded and grey, still to come.
        ClipRRect(
          borderRadius: BorderRadius.circular(BloomSpace.rSm),
          child: Opacity(
            opacity: !reached && !isNext ? .5 : 1,
            child: ColorFiltered(
              colorFilter: !reached && !isNext ? const ColorFilter.mode(Color(0xFFB8B0A0), BlendMode.saturation) : const ColorFilter.mode(Color(0x00000000), BlendMode.dst),
              child: Image.asset('assets/scenes/portrait-${milestones.indexOf(m) + 1}.webp', width: 64, height: 77, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m.tag} · ${m.title}', style: BloomText.headline.copyWith(fontSize: 16, height: 22 / 16)),
            Text(m.line, style: BloomText.caption),
            const SizedBox(height: 6),
            if (reached)
              const BloomTag(text: 'Reached', icon: Icons.check_rounded)
            else if (isNext) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: journal.toward(m)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6, color: BloomColors.mustard, backgroundColor: BloomColors.paperSunk),
                ),
              ),
              const SizedBox(height: 4),
              Text('About $moves more ${moves == 1 ? 'move' : 'moves'} · planned for ${shortDate(journal.dateOf(m))}', style: BloomText.caption),
            ] else
              Text('Planned for ${shortDate(journal.dateOf(m))}', style: BloomText.caption),
          ]),
        ),
      ]),
    );
  }
}
