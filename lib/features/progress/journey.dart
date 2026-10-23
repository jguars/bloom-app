import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../ui/bits.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
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
      Text(m.label, style: BloomText.label.copyWith(color: state == _S.later ? BloomColors.inkMuted : BloomColors.ink)),
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
/// The hallway's wooden frame colour, for portraits shown off the wall.
const _frameWood = Color(0xFFA9683A);

/// A portrait in a little wooden frame: in colour once reached; faded and grey while still to come.
class FramedPortrait extends StatelessWidget {
  const FramedPortrait({super.key, required this.index, required this.reached, this.width = 56, this.border = 4});
  final int index;
  final bool reached;
  final double width, border;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: EdgeInsets.all(border),
        decoration: BoxDecoration(
          color: _frameWood,
          borderRadius: BorderRadius.circular(border),
          boxShadow: const [BoxShadow(color: Color(0x33403A1E), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: AspectRatio(
          aspectRatio: 79 / 91,
          child: Opacity(
            opacity: reached ? 1 : .45,
            child: ColorFiltered(
              colorFilter: reached ? const ColorFilter.mode(Color(0x00000000), BlendMode.dst) : const ColorFilter.mode(Color(0xFFB8B0A0), BlendMode.saturation),
              child: Image.asset('assets/scenes/portrait-${index + 1}.webp', fit: BoxFit.cover),
            ),
          ),
        ),
      );
}

/// The headline of the Journey: the next portrait, how far along, the moves left, and the gallery so far (each
/// frame opens its portrait).
class NextPortraitCard extends StatelessWidget {
  const NextPortraitCard({super.key, required this.journal, required this.next, required this.onOpen});
  final Journal journal;
  final Milestone next;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final moves = (next.effort - journal.effort).clamp(0, 999).ceil();
    final at = milestones.indexOf(next);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: cardDecoration(radius: BloomSpace.rMd).copyWith(border: Border.all(color: BloomColors.mustard, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Eyebrow('Next portrait · ${next.title}'),
        const SizedBox(height: 4),
        Text(moves == 0 ? 'Ready to hang!' : 'About $moves more ${moves == 1 ? 'move' : 'moves'} to go', style: BloomText.headline.copyWith(fontSize: 18, height: 24 / 18)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: journal.toward(next)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: BloomColors.mustard, backgroundColor: BloomColors.paperSunk),
          ),
        ),
        const SizedBox(height: 6),
        Text('Planned for ${shortDate(journal.dateOf(next))} · moves done early bring it sooner', style: BloomText.caption),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < milestones.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Semantics(
              button: true,
              label: '${milestones[i].title} portrait',
              child: GestureDetector(
                onTap: () => onOpen(i),
                child: Container(
                  decoration: i == at ? BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: BloomColors.mustard, width: 2)) : null,
                  padding: EdgeInsets.all(i == at ? 2 : 4),
                  child: FramedPortrait(index: i, reached: journal.reached(milestones[i]), width: 40, border: 3),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Once every portrait is hung: no more portraits, just the two of them keeping at it.
class KeepGoingCard extends StatelessWidget {
  const KeepGoingCard({super.key, required this.journal});
  final Journal journal;

  @override
  Widget build(BuildContext context) {
    final since = journal.reachedDate(milestones.last);
    final moves = since == null ? journal.totalMoves : journal.movesSince(since);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EVERY PORTRAIT HUNG', style: BloomText.label.copyWith(color: BloomColors.forestPress)),
        const SizedBox(height: 2),
        Text('Keep going, together', style: BloomText.headline.copyWith(fontSize: 17)),
        const SizedBox(height: 4),
        Text(
          'The gallery is full. Clover’s staying fit with you. $moves ${moves == 1 ? 'move' : 'moves'} ${since == null ? 'in all' : 'since ${milestones.last.title.toLowerCase()}'} · best week: ${journal.bestWeek} moves.',
          style: BloomText.caption.copyWith(color: BloomColors.forestPress, fontSize: 14, height: 20 / 14),
        ),
      ]),
    );
  }
}

/// A frame from the hallway, up close: the portrait and its line once reached; what's left for the
/// next one; and, for later ones, that they come one at a time.
Future<void> showPortrait(BuildContext context, Journal journal, int index) {
  final m = milestones[index];
  final reached = journal.reached(m);
  final next = journal.next;
  final when = journal.reachedDate(m);
  final moves = (m.effort - journal.effort).clamp(0, 999).ceil();
  final detail = reached
      ? (when == null ? 'Reached.' : 'Reached ${shortDate(when)}.')
      : m == next
          ? 'About $moves more ${moves == 1 ? 'move' : 'moves'} to hang this one. Planned for ${shortDate(journal.dateOf(m))}.'
          : 'Comes after ${next!.title.toLowerCase()}. One frame at a time.';
  return showBloomSheet<void>(
    context,
    (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Center(child: FramedPortrait(index: index, reached: reached, width: 210, border: 10)),
      const SizedBox(height: 18),
      Text('${m.title}${reached ? '' : (m == next ? ' · up next' : ' · later')}', style: BloomText.title),
      const SizedBox(height: 4),
      if (reached) Text(m.line, style: BloomText.body),
      Text(detail, style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      const SizedBox(height: 18),
      LedgeButton(label: 'Back to the stairs', variant: LedgeVariant.secondary, onPressed: () => Navigator.of(c).pop()),
    ]),
  );
}
