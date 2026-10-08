import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/clock.dart';
import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/exercises.dart';
import '../../data/journal.dart';
import '../../data/today.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/room_light.dart';
import '../../ui/room_visit.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/room_frame.dart';
import '../../ui/speech_bubble.dart';
import '../urge/urge_screen.dart';
import 'check_in_sheet.dart';
import 'exercise_picker.dart';
import 'flow.dart';
import 'ready_screen.dart';

const _lines = [
  'Mm… sofa’s warm. Unless you’re coming?',
  'That was fun. Again later?',
  'One more and the ring’s full!',
  'Three! I’m so proud of us.',
];

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> with RoomVisit {
  static const _offeredKey = 'bloom.checkin.offered';
  final _chipKey = GlobalKey();

  /// The day the check-in last opened by itself, so it only does once.
  String? _offered;
  bool _offeredLoaded = false, _autoScheduled = false;

  /// Tapped the room: she purrs and says so for a moment.
  bool _tickled = false;
  int _tickles = 0;

  /// Her mood when the scene last started: a new one restarts her arrival.
  String? _mood;

  @override
  Room get visitRoom => Room.today;

  void _tickle(Offset at) {
    if (!arrived) return;
    SfxPlayer.instance.play(Sfx.purr, volume: .8);
    Feel.lightImpact();
    FxLayer.burst(at, count: 10, power: .35);
    final n = ++_tickles;
    setState(() => _tickled = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && n == _tickles) setState(() => _tickled = false);
    });
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _offered = p.getString(_offeredKey);
        _offeredLoaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(todayProvider);
    final journal = ref.watch(journalProvider);
    // Missed yesterday and nothing yet today: she waits, a little sad.
    final missed = s.done == 0 && journal.dayNumber >= 1 && journal.on(journal.todayDate.subtract(const Duration(days: 1))).moves == 0;
    ref.listen(pendingRewardProvider, (_, r) {
      if (r != null) _playReward(r);
    });
    ref.listen(checkInRequestProvider, (_, _) => _openCheckIn());
    watchVisits();
    final clockNow = ref.watch(clockProvider)();
    final evening = clockNow.hour >= kEveningHour;
    final checkIn = ref.watch(journalProvider.select((j) => j.todayLog.checkIn));
    final visible = ref.watch(roomProvider) == Room.today;
    final mood = missed ? 'sad' : s.goalMet ? 'proud' : 'think';
    if (_mood != null && mood != _mood) startVisit();
    _mood = mood;
    if (evening && checkIn == null && visible && _offeredLoaded && !_autoScheduled && _offered != s.day) {
      _autoScheduled = true;
      Future.delayed(const Duration(milliseconds: 1400), () => _autoOpen(s.day));
    }
    final mq = MediaQuery.of(context);
    final sceneH = (mq.size.height * .47).clamp(340.0, 470.0);
    final now = DateTime.now();
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return ColoredBox(
      color: BloomColors.surface,
      child: Stack(fit: StackFit.expand, children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: GestureDetector(
            onTapUp: (d) => _tickle(d.globalPosition),
            // Clover isn't home when the tab opens; after 2 s she walks in and thinks about what's next,
            // mopes after a missed day, or beams once the day is done. A new mood restarts her arrival.
            child: CloverSceneView(
              key: ValueKey('$mood-$visit'),
              scene: CloverScene.today,
              height: sceneH,
              action: missed ? CloverAction.todaySad : s.goalMet ? CloverAction.todayProud : CloverAction.todayThink,
              overlay: RoomLight(time: clockNow),
              fadeHeight: 96,
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: mq.padding.top + 12,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _Pill('${wd[now.weekday - 1]}, ${mo[now.month - 1]} ${now.day}'),
            PawChip(key: _chipKey, paws: s.paws),
          ]),
        ),
        Positioned(left: 140, right: 16, top: sceneH * (missed ? .17 : .33), child: Align(alignment: Alignment.centerLeft, child: ArrivedPop(shown: arrived, child: SpeechBubble(text: _tickled ? 'Hehe! That tickles.' : evening && checkIn != null ? checkIn.reply : missed ? 'I saved you a spot on the mat.' : _lines[s.done.clamp(0, 3)])))),
        Positioned.fill(
          top: sceneH - 40,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 0, 16, 96 + mq.padding.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TODAY', style: BloomText.label),
                    Text('Move with Clover', style: BloomText.title),
                  ]),
                ),
                // Help when a craving hits, beside the day's title (the room's moves are counted by the cards).
                _CravingButton(onTap: () => Navigator.of(context).push(bloomRoute(const UrgeScreen()))),
              ]),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 480),
                switchInCurve: BloomMotion.spring,
                switchOutCurve: BloomMotion.leave,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(.25, 0), end: Offset.zero).animate(a),
                    child: RotationTransition(turns: Tween(begin: .012, end: 0.0).animate(a), child: child),
                  ),
                ),
                child: s.goalMet
                    ? _DoneCard(key: const ValueKey('done'), onMore: _pickMore)
                    : _PickCard(
                        key: ValueKey(s.current.id),
                        ex: s.current,
                        onGo: () => _open(s.current),
                        onSwap: () => ref.read(todayProvider.notifier).swap(),
                      ),
              ),
              if (evening) ...[
                const SizedBox(height: 12),
                RiseIn(delay: const Duration(milliseconds: 200), child: _CheckInRow(answer: checkIn, onTap: _openCheckIn)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  void _open(Exercise ex) => Navigator.of(context).push(bloomRoute(ReadyScreen(ex: ex)));

  /// After the day's three, any move can be picked from the full list.
  Future<void> _pickMore() async {
    final ex = await showExercisePicker(context, ref);
    if (ex != null && mounted) _open(ex);
  }

  /// Opens the check-in by itself, once per evening, when nothing else is
  /// happening on Today.
  Future<void> _autoOpen(String day) async {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final busy = !(route?.isCurrent ?? true) || ref.read(pendingRewardProvider) != null || ref.read(roomProvider) != Room.today;
    if (busy) {
      _autoScheduled = false; // try again next time Today rebuilds
      return;
    }
    _offered = day;
    (await SharedPreferences.getInstance()).setString(_offeredKey, day);
    if (mounted) _openCheckIn();
  }

  Future<void> _openCheckIn() async {
    final r = await showBloomSheet<CheckInResult>(context, (c) => const CheckInSheet());
    if (r == null || !mounted) return;
    SfxPlayer.instance.play(r.answer == CheckIn.all ? Sfx.cheer : Sfx.chime);
    Feel.mediumImpact();
    final size = MediaQuery.of(context).size;
    if (r.answer == CheckIn.all) FxLayer.burst(Offset(size.width / 2, size.height * .35), count: 60, power: .9);
    if (!r.first) return;
    final chip = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    final target = chip == null ? Offset(size.width - 60, 70) : chip.localToGlobal(chip.size.center(Offset.zero));
    final from = r.from == Offset.zero ? Offset(size.width / 2, size.height * .7) : r.from;
    FxLayer.fly(from, target, '+$kCheckInPaws', delay: const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) ref.read(todayProvider.notifier).addPaws(kCheckInPaws);
  }

  /// Paw chips fly from the middle of the screen into the balance, then the
  /// balance counts up; filling the ring adds a burst and the bonus.
  Future<void> _playReward(Reward r) async {
    ref.read(pendingRewardProvider.notifier).set(null);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final chip = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    final target = chip == null ? Offset(size.width - 60, 70) : chip.localToGlobal(chip.size.center(Offset.zero));
    final from = Offset(size.width / 2, size.height * .62);
    const n = 5;
    for (var i = 0; i < n; i++) {
      FxLayer.fly(from + Offset((i - 2) * 22.0, 0), target, '+${(r.paws / n).round()}', delay: Duration(milliseconds: i * 110));
    }
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    ref.read(todayProvider.notifier).addPaws(r.paws);
    if (r.bonus > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      FxLayer.burst(Offset(size.width / 2, size.height * .45), count: 90);
      FxLayer.fly(from, target, '+${r.bonus}', delay: const Duration(milliseconds: 300));
      await Future<void>.delayed(const Duration(milliseconds: 1250));
      if (!mounted) return;
      ref.read(todayProvider.notifier).addPaws(r.bonus);
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: BloomColors.surface, borderRadius: BorderRadius.circular(BloomSpace.rPill), boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1))]),
        child: Text(text, style: BloomText.button.copyWith(fontSize: 14)),
      );
}

BoxDecoration get _cardDeco => BoxDecoration(
      color: BloomColors.surface,
      borderRadius: BorderRadius.circular(BloomSpace.rLg),
      boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1)), BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10))],
    );

class _PickCard extends StatelessWidget {
  const _PickCard({super.key, required this.ex, required this.onGo, required this.onSwap});
  final Exercise ex;
  final VoidCallback onGo, onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const _MoveTile(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HER PICK FOR YOU', style: BloomText.label),
              const SizedBox(height: 2),
              Text(ex.name, style: BloomText.headline),
              Text('${ex.meta} · +${ex.paws} paws', style: BloomText.caption),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        LedgeButton(label: 'Let’s do it together', onPressed: onGo, glow: true),
        const SizedBox(height: 6),
        Center(child: LedgeButton(label: 'Show me something else', onPressed: onSwap, variant: LedgeVariant.ghost, expand: false)),
      ]),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({super.key, required this.onMore});
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco,
        child: Column(children: [
          Text('DAY COMPLETE', style: BloomText.label),
          const SizedBox(height: 4),
          Text('That’s three today!', style: BloomText.title),
          const SizedBox(height: 10),
          const PopIn(delay: Duration(milliseconds: 300), child: EarnChip(text: '+15 bonus')),
          const SizedBox(height: 10),
          Text('Clover’s resting now. You can still do one more if you feel like it.', textAlign: TextAlign.center, style: BloomText.bodyMuted.copyWith(fontSize: 15)),
          const SizedBox(height: 14),
          LedgeButton(label: 'Do one more anyway', onPressed: onMore, variant: LedgeVariant.secondary),
        ]),
      );
}

/// Exercise tile with a little wiggle every few seconds.
class _MoveTile extends StatefulWidget {
  const _MoveTile();
  @override
  State<_MoveTile> createState() => _MoveTileState();
}

class _MoveTileState extends State<_MoveTile> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final a = t < .8 ? 0.0 : (t < .85 ? -.1 : t < .9 ? .1 : t < .95 ? -.05 : 0.0);
          return Transform.rotate(angle: a, child: child);
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
          child: const Icon(Icons.directions_run_rounded, color: BloomColors.sageDeep, size: 34),
        ),
      );
}

/// Evening only: the way into the check-in, or what was answered.
class _CheckInRow extends StatelessWidget {
  const _CheckInRow({required this.answer, required this.onTap});
  final CheckIn? answer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = answer != null;
    return Semantics(
      button: true,
      label: done ? 'Checked in: ${answer!.label}. Change it' : 'How did today go? Check in',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: done ? BloomColors.forestSoft : BloomColors.surface,
            borderRadius: BorderRadius.circular(BloomSpace.rMd),
            border: Border.all(color: done ? Colors.transparent : BloomColors.mustard, width: 2),
            boxShadow: done ? null : const [BoxShadow(color: BloomColors.mustardSoft, offset: Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: done ? BloomColors.surface : BloomColors.mustardSoft, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
              child: Icon(done ? Icons.check_rounded : Icons.nightlight_round, color: done ? BloomColors.forest : BloomColors.mustardPress, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(done ? 'Checked in · ${answer!.label}' : 'How did today go?', style: BloomText.headline.copyWith(fontSize: 16, height: 22 / 16)),
                Text(done ? 'Tap to change it' : 'Evening check-in · +$kCheckInPaws paws', style: BloomText.caption),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: BloomColors.inkMuted),
          ]),
        ),
      ),
    );
  }
}


/// The round "Craving?" button in Today's header: a deep-sky disc with a wave and its name, and a
/// soft ring that breathes so it reads as something to tap.
class _CravingButton extends StatefulWidget {
  const _CravingButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CravingButton> createState() => _CravingButtonState();
}

class _CravingButtonState extends State<_CravingButton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Craving something? Ride it out with Clover',
        child: GestureDetector(
          onTap: () {
            Feel.selectionClick();
            widget.onTap();
          },
          child: SizedBox(
            width: 84,
            height: 84,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = MediaQuery.of(context).disableAnimations ? 0.0 : _pulse.value;
                return Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 70 + 14 * t,
                    height: 70 + 14 * t,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: BloomColors.skyDeep.withValues(alpha: .22 * (1 - t))),
                  ),
                  child!,
                ]);
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: BloomColors.skyDeep,
                  boxShadow: [BoxShadow(color: Color(0x3324485A), blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.waves_rounded, size: 24, color: BloomColors.surface),
                  Text('Craving?', style: BloomText.label.copyWith(fontSize: 11, letterSpacing: .2, color: BloomColors.surface)),
                ]),
              ),
            ),
          ),
        ),
      );
}
