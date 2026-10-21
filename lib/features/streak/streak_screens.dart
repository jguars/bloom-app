import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/streak.dart';
import '../../data/today.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/speech_bubble.dart';
import '../today/flow.dart';
import '../today/ready_screen.dart' show RoundButton;

// --- Pieces -----------------------------------------------------------------------------------------------------------

/// A Paw Patch: a little mustard fabric patch, stitched round the edge, with a paw on it. It covers a missed day.
class PawPatch extends StatelessWidget {
  const PawPatch({super.key, this.size = 40, this.faded = false});
  final double size;
  final bool faded;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: faded ? .35 : 1,
    child: Transform.rotate(
      angle: -.08,
      child: CustomPaint(size: Size.square(size), painter: _PatchPainter()),
    ),
  );
}

class _PatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * .28));
    canvas.drawRRect(r.shift(Offset(0, s * .05)), Paint()..color = BloomColors.mustardPress);
    canvas.drawRRect(r, Paint()..color = BloomColors.mustard);
    // stitches: a dashed line just inside the edge
    final inner = r.deflate(s * .1);
    final path = Path()..addRRect(inner);
    final stitch = Paint()
      ..color = BloomColors.surface.withValues(alpha: .9)
      ..strokeWidth = math.max(1, s * .045)
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += s * .14) {
        final a = m.getTangentForOffset(d)!.position, b = m.getTangentForOffset(math.min(d + s * .07, m.length))!.position;
        canvas.drawLine(a, b, stitch);
      }
    }
    canvas.save();
    canvas.translate(s * .2, s * .18);
    final paw = Size.square(s * .6);
    final p = Paint()..color = BloomColors.mustardPress;
    final k = paw.width / 24;
    canvas.drawOval(Rect.fromCenter(center: Offset(12 * k, 16 * k), width: 10.4 * k, height: 8.8 * k), p);
    for (final c in const [Offset(5.6, 10.4), Offset(9.4, 6.6), Offset(14.6, 6.6), Offset(18.4, 10.4)]) {
      canvas.drawCircle(c * k, 2.3 * k, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatchPainter old) => false;
}

/// The streak badge: a mustard sun with a check, glowing once today counts.
class StreakSun extends StatelessWidget {
  const StreakSun({super.key, this.size = 28, this.lit = true});
  final double size;
  final bool lit;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _SunPainter(lit));
}

class _SunPainter extends CustomPainter {
  _SunPainter(this.lit);
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2;
    final fill = Paint()..color = lit ? BloomColors.mustard : BloomColors.line;
    final path = Path();
    const n = 12;
    for (var i = 0; i <= n * 2; i++) {
      final a = i * math.pi / n - math.pi / 2, rr = i.isEven ? r : r * .82;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, fill);
    canvas.drawCircle(c, r * .66, Paint()..color = lit ? BloomColors.mustardSoft : BloomColors.paperSunk);
    final tick = Paint()
      ..color = lit ? BloomColors.mustardPress : BloomColors.lineStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * .32, c.dy + r * .02)
        ..lineTo(c.dx - r * .08, c.dy + r * .26)
        ..lineTo(c.dx + r * .34, c.dy - r * .22),
      tick,
    );
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.lit != lit;
}

/// The streak in the Progress room's top-right corner: the sun and the days in a row. Opens the streak page.
class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  /// The streak on the Progress title row: a gold pill like the Plan's "On my plan?" and the Shop's "Plus" (44 tall, a
  /// white disc with the sun, then the count). Opens the streak.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(streakNowProvider);
    return Semantics(
      button: true,
      label: '${s.current} day streak',
      child: GestureDetector(
        onTap: () {
          Feel.selectionClick();
          Navigator.of(context).push(bloomRoute(const StreakScreen()));
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          decoration: BoxDecoration(
            color: BloomColors.mustard,
            borderRadius: BorderRadius.circular(BloomSpace.rPill),
            boxShadow: const [BoxShadow(color: Color(0x3366551C), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle),
                child: StreakSun(size: 26, lit: s.doneToday),
              ),
              const SizedBox(width: 8),
              Text(s.current == 1 ? '1 day' : '${s.current} days', style: BloomText.button.copyWith(fontSize: 14, color: BloomColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A week of the streak, Monday to Sunday: ticks for days moved, a patch where one covered a miss, a soft mark for
/// a miss, and today ringed.
class StreakWeek extends StatelessWidget {
  const StreakWeek({super.key, required this.streak, required this.journal, this.dot = 34});
  final Streak streak;
  final Journal journal;
  final double dot;

  @override
  Widget build(BuildContext context) {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final week = journal.week;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (i, d) in week.indexed)
          Column(
            children: [
              Text(names[i], style: BloomText.label),
              const SizedBox(height: 6),
              PopIn(
                delay: Duration(milliseconds: 380 + 60 * i),
                child: _DayDot(kind: streak.dayOf(d), today: dayKey(d) == journal.today, size: dot),
              ),
            ],
          ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.kind, required this.today, this.size = 34});
  final StreakDay kind;
  final bool today;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (kind == StreakDay.patched) {
      return SizedBox.square(
        dimension: size,
        child: Center(child: PawPatch(size: size * .86)),
      );
    }
    final moved = kind == StreakDay.moved;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: moved ? BloomColors.forest : (kind == StreakDay.missed ? BloomColors.paperSunk : BloomColors.surface),
        border: Border.all(color: today ? BloomColors.mustard : (moved ? BloomColors.forest : BloomColors.line), width: today ? 3 : 2),
        boxShadow: moved ? const [BoxShadow(color: BloomColors.forestPress, offset: Offset(0, 2))] : null,
      ),
      child: moved ? Icon(Icons.check_rounded, color: BloomColors.onForest, size: size * .6) : null,
    );
  }
}

String _days(int n) => n == 1 ? '1 day' : '$n days';

// --- Celebration ------------------------------------------------------------------------------------------------------

/// After the day's first move: Clover leaps, the streak count rolls up to today's, and the week fills in. Every
/// [kDaysPerPatch] days in a row earns a Paw Patch. Collect hands the move's reward on to Today, as the move's own
/// celebration does.
class StreakCelebrationScreen extends ConsumerStatefulWidget {
  const StreakCelebrationScreen({super.key, required this.reward});
  final Reward reward;

  @override
  ConsumerState<StreakCelebrationScreen> createState() => _StreakCelebrationScreenState();
}

class _StreakCelebrationScreenState extends ConsumerState<StreakCelebrationScreen> {
  bool _earned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Marked celebrated (and a patch earned, every week in a row) once the screen is up.
      final earned = ref.read(streakProvider.notifier).celebrate(ref.read(journalProvider));
      if (mounted && earned) setState(() => _earned = true);
      SfxPlayer.instance.play(Sfx.cheer);
      Feel.mediumImpact();
      final size = MediaQuery.of(context).size;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      FxLayer.burst(Offset(size.width * .5, size.height * .3), count: 60);
      if (_earned) {
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        SfxPlayer.instance.play(Sfx.flag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = ref.watch(streakNowProvider);
    final j = ref.watch(journalProvider);
    final sceneH = (mq.size.height * .42).clamp(300.0, 400.0);
    final n = s.current;
    final line = switch (n) {
      1 => 'Day one of our streak! Same time tomorrow?',
      _ when n == s.longest && n > 2 => 'Our longest streak yet. Look at us!',
      _ when n % kDaysPerPatch == 0 => '${_days(n)} in a row. A whole week of us!',
      _ => '${_days(n)} of moving together. Same time tomorrow?',
    };
    return Scaffold(
      backgroundColor: BloomColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: CloverSceneView(scene: CloverScene.cheer, height: sceneH, cheering: true, fadeHeight: 80),
          ),
          Positioned.fill(
            top: sceneH - 40,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + mq.padding.bottom),
              child: Column(
                children: [
                  PopIn(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: math.max(0, n - 1).toDouble(), end: n.toDouble()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Text('${v.round()}', style: BloomText.displayXl.copyWith(fontSize: 72, height: 1, color: BloomColors.forest)),
                    ),
                  ),
                  RiseIn(
                    delay: const Duration(milliseconds: 150),
                    child: Text('DAY STREAK', style: BloomText.label.copyWith(fontSize: 15, color: BloomColors.forest)),
                  ),
                  const SizedBox(height: 18),
                  RiseIn(
                    delay: const Duration(milliseconds: 260),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      decoration: BoxDecoration(
                        color: BloomColors.paper,
                        borderRadius: BorderRadius.circular(BloomSpace.rLg),
                        boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 2))],
                      ),
                      child: StreakWeek(streak: s, journal: j),
                    ),
                  ),
                  const SizedBox(height: 14),
                  RiseIn(
                    delay: const Duration(milliseconds: 420),
                    child: Text(line, textAlign: TextAlign.center, style: BloomText.bodyMuted),
                  ),
                  if (_earned) ...[
                    const SizedBox(height: 12),
                    PopIn(
                      delay: const Duration(milliseconds: 1300),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                        decoration: BoxDecoration(color: BloomColors.mustardSoft, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PawPatch(size: 26),
                            const SizedBox(width: 8),
                            Text('You earned a Paw Patch!', style: BloomText.button.copyWith(fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  RiseIn(
                    delay: const Duration(milliseconds: 500),
                    child: LedgeButton(
                      label: widget.reward.paws > 0 ? 'Collect ${widget.reward.paws}' : 'Keep it going',
                      variant: LedgeVariant.reward,
                      glow: true,
                      leading: widget.reward.paws > 0 ? const PawIcon(color: BloomColors.ink, size: 20) : null,
                      onPressed: () {
                        ref.read(pendingRewardProvider.notifier).set(widget.reward);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- The streak page --------------------------------------------------------------------------------------------------

/// The streak up close: today's count and the longest, Paw Patches on hand, and the month's calendar with the run
/// of days joined up.
class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = ref.watch(streakNowProvider);
    final j = ref.watch(journalProvider);
    final toNext = kDaysPerPatch - s.current % kDaysPerPatch;
    return Scaffold(
      backgroundColor: BloomColors.paper,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, mq.padding.top + 8, 20, 32 + mq.padding.bottom),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: RoundButton(icon: Icons.close_rounded, label: 'Close', onTap: () => Navigator.of(context).pop()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              PopIn(child: StreakSun(size: 92, lit: s.doneToday)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.current}', style: BloomText.displayXl.copyWith(fontSize: 56, height: 1)),
                    Text('day streak', style: BloomText.headline),
                    const SizedBox(height: 2),
                    Text('Longest: ${_days(s.longest)}', style: BloomText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.doneToday ? 'Today counts. See you tomorrow!' : 'One move today keeps it going.', style: BloomText.bodyMuted),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: BloomColors.surface,
              borderRadius: BorderRadius.circular(BloomSpace.rLg),
              boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paw Patches', style: BloomText.headline),
                            const SizedBox(height: 2),
                            Text('Covers a day you miss, so the streak carries on.', style: BloomText.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Row(
                            children: [
                              for (var i = 0; i < kMaxPatches; i++)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: PawPatch(size: 30, faded: i >= s.patches),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${s.patches}/$kMaxPatches on hand', style: BloomText.label.copyWith(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: BloomColors.mustardSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    s.patches >= kMaxPatches ? 'Your patch pocket is full.' : '${_days(toNext)} more in a row to earn a patch.',
                    style: BloomText.button.copyWith(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Clover peeking up over the calendar.
          SizedBox(
            height: 92,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(left: 0, right: 0, bottom: -26, height: 128, child: LiveClover(action: CloverAction.cheer)),
                Positioned(right: 70, top: 14, child: Icon(Icons.favorite_rounded, size: 18, color: BloomColors.coral.withValues(alpha: .9))),
              ],
            ),
          ),
          _Calendar(streak: s, journal: j),
        ],
      ),
    );
  }
}

/// The streak calendar: one month per page, swiped (it follows the finger) or stepped with the arrows. Goes back a
/// year (or to the journey's start, if earlier) and forward to this month.
class _Calendar extends StatefulWidget {
  const _Calendar({required this.streak, required this.journal});
  final Streak streak;
  final Journal journal;

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  static const _names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _cell = 36.0, _gap = 6.0;

  late final DateTime _last = DateTime(widget.journal.todayDate.year, widget.journal.todayDate.month);
  late final DateTime _first = () {
    final start = DateTime(widget.journal.startDate.year, widget.journal.startDate.month);
    final yearBack = DateTime(_last.year, _last.month - 12);
    return start.isBefore(yearBack) ? start : yearBack;
  }();
  late final int _count = (_last.year - _first.year) * 12 + _last.month - _first.month + 1;
  late final _pages = PageController(initialPage: _count - 1);
  late int _page = _count - 1;

  DateTime _monthAt(int i) => DateTime(_first.year, _first.month + i);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final month = _monthAt(_page);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(color: BloomColors.surface, borderRadius: BorderRadius.circular(BloomSpace.rLg), boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 2))]),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: _page > 0 ? () => _go(_page - 1) : null, icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text('${_names[month.month - 1]} ${month.year}', key: ValueKey(month), textAlign: TextAlign.center, style: BloomText.headline),
            ),
          ),
          IconButton(onPressed: _page < _count - 1 ? () => _go(_page + 1) : null, icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        Row(children: [for (final n in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Text(n, textAlign: TextAlign.center, style: BloomText.label))]),
        const SizedBox(height: 6),
        // Six rows always fit, so every month has the same height and the page doesn't jump.
        SizedBox(
          height: 6 * (_cell + _gap),
          child: PageView.builder(
            controller: _pages,
            itemCount: _count,
            onPageChanged: (i) {
              Feel.selectionClick();
              setState(() => _page = i);
            },
            itemBuilder: (context, i) => _MonthGrid(month: _monthAt(i), streak: widget.streak, journal: widget.journal),
          ),
        ),
      ]),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.streak, required this.journal});
  final DateTime month;
  final Streak streak;
  final Journal journal;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = month.weekday - 1;
    final today = journal.todayDate;
    bool on(DateTime d) => const {StreakDay.moved, StreakDay.patched}.contains(streak.dayOf(d));
    return Column(children: [
      for (var row = 0; row * 7 < lead + days; row++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(
                child: Builder(builder: (context) {
                  final n = row * 7 + col - lead + 1;
                  if (n < 1 || n > days) return const SizedBox(height: 36);
                  final d = DateTime(month.year, month.month, n);
                  // Days before the journey or after today are blank.
                  final inJourney = !d.isBefore(journal.startDate) && !d.isAfter(today);
                  final kind = streak.dayOf(d);
                  final lit = inJourney && on(d);
                  // The run of days is one pill: round only where it starts and ends.
                  final joinL = lit && col > 0 && n > 1 && on(d.subtract(const Duration(days: 1)));
                  final joinR = lit && col < 6 && n < days && on(d.add(const Duration(days: 1)));
                  final isToday = dayKey(d) == journal.today;
                  return Container(
                    height: 36,
                    margin: EdgeInsets.only(left: joinL ? 0 : 2, right: joinR ? 0 : 2),
                    decoration: BoxDecoration(
                      color: lit ? BloomColors.forestSoft : null,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(joinL ? 0 : 18), right: Radius.circular(joinR ? 0 : 18)),
                    ),
                    alignment: Alignment.center,
                    child: inJourney && kind == StreakDay.patched
                        ? const PawPatch(size: 24)
                        : Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: isToday ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: BloomColors.mustard, width: 2.5)) : null,
                            child: Text('$n',
                                style: BloomText.button.copyWith(
                                  fontSize: 14,
                                  color: lit ? BloomColors.forest : (inJourney ? BloomColors.inkMuted : BloomColors.line),
                                )),
                          ),
                  );
                }),
              ),
          ]),
        ),
    ]);
  }
}

// --- Missed a day -----------------------------------------------------------------------------------------------------

/// After a missed day (or two) with a streak worth saving: Clover, kindly, offers a Paw Patch to cover it, or to
/// start fresh. Never shaming.
class StreakPatchScreen extends ConsumerWidget {
  const StreakPatchScreen({super.key, required this.gap});
  final ({String from, int days, int run}) gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final s = ref.watch(streakNowProvider);
    final which = gap.days == 1 ? 'yesterday' : 'the last ${gap.days} days';
    return Scaffold(
      backgroundColor: BloomColors.paper,
      body: Padding(
        padding: EdgeInsets.fromLTRB(24, mq.padding.top + 24, 24, 24 + mq.padding.bottom),
        child: Column(
          children: [
            const RiseIn(child: SpeechBubble(text: 'It’s okay to miss a day. You’re here now, and that’s what counts.', maxWidth: 300)),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(child: LiveClover(action: CloverAction.reach)),
                  Positioned(
                    right: mq.size.width * .14,
                    top: 30,
                    child: PopIn(
                      delay: const Duration(milliseconds: 400),
                      child: _Bob(child: PawPatch(size: 64)),
                    ),
                  ),
                ],
              ),
            ),
            Text('Patch your ${gap.run}-day streak?', textAlign: TextAlign.center, style: BloomText.title),
            const SizedBox(height: 4),
            Text('A Paw Patch covers $which, and the streak carries on.', textAlign: TextAlign.center, style: BloomText.bodyMuted),
            const SizedBox(height: 20),
            LedgeButton(
              label: gap.days == 1 ? 'Patch it  (${s.patches} on hand)' : 'Use ${gap.days} patches  (${s.patches} on hand)',
              leading: const PawPatch(size: 22),
              onPressed: () {
                ref.read(streakProvider.notifier).patch(ref.read(journalProvider), gap);
                SfxPlayer.instance.play(Sfx.check);
                Feel.mediumImpact();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 10),
            LedgeButton(
              label: 'Start fresh',
              variant: LedgeVariant.secondary,
              onPressed: () {
                ref.read(streakProvider.notifier).startFresh(gap);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Bob extends StatefulWidget {
  const _Bob({required this.child});
  final Widget child;
  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, 6 * math.sin(_c.value * 2 * math.pi)),
      child: Transform.rotate(angle: .06 * math.sin(_c.value * 2 * math.pi + 1), child: child),
    ),
    child: widget.child,
  );
}
