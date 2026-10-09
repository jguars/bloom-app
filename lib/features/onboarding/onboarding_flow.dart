import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/clock.dart';
import '../../app/gate.dart';
import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/reminders.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/profile.dart';
import '../../data/today.dart';
import '../../data/weight.dart';
import '../../ui/ambience.dart';
import '../../ui/bits.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/room_frame.dart';
import '../../ui/room_light.dart';
import '../../ui/window_sky.dart';
import '../../ui/weight_chart.dart';
import '../paywall/paywall_screen.dart';
import '../progress/journey.dart';
import '../progress/weight_sheet.dart';
import 'ob_stage.dart';
import 'ob_widgets.dart';

/// The pages, in order. Clover leads every one from a live room at the top: she arrives on the porch,
/// gets her name, asks yours from the sofa, and walks you through the house as you answer.
enum _Step { welcome, catName, name, why, numbers, pace, body, reminders, building, journey, paywall }

/// Why you're here: what she says back, the painted icon on the card and how she acts it out.
const _reasons = {
  'Lose some weight': ('A little lighter, every week. Gently!', 'stairs', CloverAction.exDance),
  'Move more every day': ('Let’s get these paws moving!', 'walk', CloverAction.cheer),
  'Feel lighter and calmer': ('Deep breaths and short walks. I’m in.', 'sleep', CloverAction.exStretch),
  'Build better habits': ('Little habits, big bloom!', 'water', CloverAction.exSquat),
};

/// kg a week, its name, and what she says.
const _paces = [
  (0.5, 'Gentle', 'Nice and easy. This is my stroll.'),
  (0.7, 'Steady', 'Steady it is! My favourite walk.'),
  (1.0, 'Brisk', 'Ooh, brisk! Keep up!'),
];

const _activities = {
  'Mostly sitting': 'Same! We’ll start light.',
  'Some walking': 'Good base! Let’s build on it.',
  'On my feet a lot': 'Wow! You’ll outpace me.',
  'Not sure': 'No problem. We’ll find out together.',
};

const _limits = {'knees': 'Knees', 'back': 'Back', 'wrists': 'Wrists', 'shoulders': 'Shoulders'};

/// Names to shuffle through for her.
const _catNames = ['Clover', 'Maple', 'Mochi', 'Biscuit', 'Pip', 'Hazel', 'Toffee', 'Juniper', 'Pudding', 'Olive'];

/// The first run: meet Clover, a few questions she asks herself, the road you'll walk together, then Plus.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  var _step = _Step.welcome;
  var _forward = true;

  // Answers.
  final _cat = TextEditingController(text: 'Clover');
  final _name = TextEditingController();
  String? _reason, _activity;
  bool _pounds = false;
  double _kg = 80, _goal = 74, _pace = .7;
  final Set<String> _easy = {};
  bool _noLimits = false;
  bool _morning = true, _evening = true;
  int _morningAt = 8 * 60, _eveningAt = 20 * 60 + 30;

  /// Which nudge's time the bedroom sky shows (the last one touched).
  int _skyAt = 8 * 60;

  /// A short act she plays in answer to a tap, over whatever she was doing.
  CloverAction? _react;
  Timer? _reactTimer;

  /// Getting off the sofa on the way from your name to the first question.
  bool _gettingUp = false;
  Timer? _upTimer;

  /// A line she says for a moment (a tickle), over the page's own.
  String? _quip;
  Timer? _quipTimer;

  /// The "drawing our road" page: how many answers have checked in.
  int _ticks = 0;
  Timer? _tickTimer;

  final _startKey = GlobalKey();
  final _stageKey = GlobalKey();

  String get _catName => _cat.text.trim().isEmpty ? 'Clover' : _cat.text.trim();
  String get _you => _name.text.trim();

  /// Debug: `--dart-define=OB_TOUR=true` walks the pages by itself with sample answers (for screen
  /// recordings on a device that won't take injected taps).
  static const _tour = bool.fromEnvironment('OB_TOUR');
  Timer? _tourTimer;

  void _tourStep() {
    switch (_step) {
      case _Step.name:
        if (_you.isEmpty) {
          _name.text = 'Sam';
          setState(() {});
          return;
        }
        _meetYou();
      case _Step.why:
        if (_reason == null) {
          setState(() => _reason = 'Move more every day');
          _act(CloverAction.cheer);
          return;
        }
        _next();
      case _Step.body:
        if (_activity == null) {
          setState(() {
            _activity = 'Some walking';
            _easy.add('knees');
          });
          return;
        }
        _next();
      case _Step.building || _Step.journey || _Step.paywall:
        return;
      default:
        _next();
    }
  }

  @override
  void initState() {
    super.initState();
    if (_tour) _tourTimer = Timer.periodic(const Duration(milliseconds: 4200), (_) => _tourStep());
    // Decode the rooms ahead, so each one is ready the moment she walks into it (not in widget tests,
    // which can't load Rive).
    if (CloverRive.nativeReady && !Platform.environment.containsKey('FLUTTER_TEST')) {
      for (final s in [CloverScene.ready, CloverScene.today, CloverScene.plan, CloverScene.march, CloverScene.gym, CloverScene.profile, CloverScene.progress, CloverScene.cheer]) {
        s.load();
      }
    }
  }

  @override
  void dispose() {
    _cat.dispose();
    _name.dispose();
    _reactTimer?.cancel();
    _upTimer?.cancel();
    _quipTimer?.cancel();
    _tickTimer?.cancel();
    _tourTimer?.cancel();
    super.dispose();
  }

  void _go(_Step s) {
    FocusScope.of(context).unfocus();
    _tickTimer?.cancel();
    _reactTimer?.cancel();
    setState(() {
      _forward = s.index > _step.index;
      _step = s;
      _react = null;
      _quip = null;
    });
    if (s == _Step.building) _drawRoad();
    if (s == _Step.journey) _confetti();
  }

  void _next() => _go(_Step.values[_step.index + 1]);
  void _back() {
    if (_step == _Step.why) _gettingUp = false;
    _go(_Step.values[_step.index - (_step == _Step.journey ? 2 : 1)]);
  }

  /// She acts out a tap for a moment, then goes back to what she was doing.
  void _act(CloverAction a, {Duration dur = const Duration(milliseconds: 2600)}) {
    _reactTimer?.cancel();
    setState(() => _react = a);
    _reactTimer = Timer(dur, () {
      if (mounted) setState(() => _react = null);
    });
  }

  /// A small spray of sparkles where you tapped.
  void _sparkle(Offset at, {int count = 12, double power = .35}) {
    SfxPlayer.instance.play(Sfx.pop, volume: .5);
    FxLayer.burst(at, count: count, power: power);
  }

  Offset _stageAt(double fx, double fy) {
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(Offset(box.size.width * fx, box.size.height * fy));
  }

  void _tickle(Offset at) {
    SfxPlayer.instance.play(Sfx.purr, volume: .8);
    Feel.lightImpact();
    FxLayer.burst(at, count: 10, power: .35);
    _quipTimer?.cancel();
    setState(() => _quip = 'Hehe! That tickles.');
    _quipTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _quip = null);
    });
  }

  void _shuffleCat() {
    final now = _catName;
    final pool = _catNames.where((n) => n != now).toList();
    _cat.text = pool[math.Random().nextInt(pool.length)];
    Feel.selectionClick();
    _sparkle(_stageAt(.5, .4), count: 16, power: .45);
    setState(() {});
  }

  void _meetYou() {
    FocusScope.of(context).unfocus();
    _upTimer?.cancel();
    _gettingUp = true;
    _upTimer = Timer(CloverAction.getUpTime, () {
      if (mounted) setState(() => _gettingUp = false);
    });
    _next();
  }

  /// The pause before the reveal: each answer checks in, then the road appears.
  void _drawRoad() {
    _ticks = 0;
    _tickTimer = Timer.periodic(const Duration(milliseconds: 560), (t) {
      if (!mounted) return t.cancel();
      if (_ticks < 5) {
        Feel.selectionClick();
        setState(() => _ticks++);
      } else {
        t.cancel();
        _next();
      }
    });
  }

  void _confetti() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 520), () {
        if (!mounted) return;
        SfxPlayer.instance.play(Sfx.cheer, volume: .6);
        FxLayer.burst(_stageAt(.5, .55), count: 46, power: .9);
      });
    });
  }

  Units get _units => Units(_pounds);

  DateTime? _goalDate(double pace) {
    final diff = _kg - _goal;
    if (diff <= .05) return null;
    return DateTime.now().add(Duration(days: (diff / pace * 7).round()));
  }

  Future<void> _turnOnReminders() async {
    final ok = await Reminders.requestPermission();
    if (!mounted) return;
    if (!ok) setState(() => _morning = _evening = false);
    _next();
  }

  /// Saves every answer, then celebrates on the way to the paywall.
  void _start() {
    final profile = ref.read(profileProvider.notifier);
    profile.update(ref.read(profileProvider).copyWith(
          name: _you,
          catName: _catName,
          pounds: _pounds,
          reason: _reason ?? '',
          activity: _activity ?? '',
          limits: _easy,
          morning: _morning,
          evening: _evening,
          morningAt: _morningAt,
          eveningAt: _eveningAt,
        ));
    final w = ref.read(weightProvider.notifier);
    if (ref.read(weightProvider).entries.isEmpty) w.log(_kg);
    w.setGoal(_goal);
    w.setPace(_pace);
    ref.read(todayProvider.notifier).setPreferences(limits: _easy, gentle: _activity == 'Mostly sitting');

    SfxPlayer.instance.play(Sfx.cheer);
    Feel.heavyImpact();
    final box = _startKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final c = box.localToGlobal(box.size.center(Offset.zero));
      FxLayer.burst(c, count: 40, power: 1);
      Future.delayed(const Duration(milliseconds: 220), () => FxLayer.burst(c + const Offset(-90, -60), count: 24, power: .8));
      Future.delayed(const Duration(milliseconds: 420), () => FxLayer.burst(c + const Offset(90, -80), count: 24, power: .8));
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _next();
    });
  }

  void _finish() {
    ref.read(profileProvider.notifier).update(ref.read(profileProvider).copyWith(onboarded: true));
    AppGate.forceOnboarding.value = false;
  }

  // ---------------------------------------------------------------------------------------------
  // The stage: which room, what she's doing, what she says.

  String _limitsLine() {
    final picked = _easy.map((k) => _limits[k]!.toLowerCase()).toList();
    if (_noLimits) return 'Great! Every move is on the table.';
    if (picked.isNotEmpty) return '${_list(picked, capital: true)} noted${_you.isEmpty ? '' : ', $_you'}. I’ll go easy on ${picked.length == 1 ? 'it' : 'them'}.';
    if (_activity != null) return _activities[_activity]!;
    return 'Warming up! Anything sore? Tell me.';
  }

  (StageSpec, String?, Alignment) _stage() {
    final you = _you;
    switch (_step) {
      case _Step.welcome || _Step.paywall:
        return (const StageSpec.still('assets/scenes/porch.jpg', ambience: AmbienceKind.pollen, alignment: Alignment(0, -.2)), 'Oh! A visitor!', const Alignment(.15, .05));
      case _Step.catName:
        final named = _cat.text.trim().isNotEmpty && _catName != 'Clover';
        return (
          const StageSpec.room(CloverScene.ready, eyesOpen: true, ambience: AmbienceKind.sparkles, framing: Alignment(0, -.45)),
          named ? '$_catName! I love it!' : 'I’m yours now! What will you call me?',
          const Alignment(-.7, -.5),
        );
      case _Step.name:
        return (
          StageSpec.room(CloverScene.today, action: you.isEmpty ? CloverAction.todayLazy : CloverAction.todayStir, ambience: AmbienceKind.dust, overlay: RoomLight(time: ref.watch(clockProvider)())),
          you.isEmpty ? 'I’m $_catName! And you are…?' : '$you! Come in, the sofa’s warm.',
          const Alignment(-.55, -.4),
        );
      case _Step.why:
        final a = _react ?? (_gettingUp ? CloverAction.todayGetUp : CloverAction.rest);
        final line = _reason == null ? (you.isEmpty ? 'Tell me everything!' : 'Ooh, tell me everything, $you!') : _reasons[_reason]!.$1;
        return (StageSpec.room(CloverScene.today, action: a, ambience: AmbienceKind.dust, overlay: RoomLight(time: ref.watch(clockProvider)())), line, const Alignment(-.6, -.45));
      case _Step.numbers:
        final diff = _kg - _goal;
        final line = diff > .05 ? '${_units.short(diff)}, a little every day. Like my lavender!' : 'Staying active? Me too!';
        return (const StageSpec.room(CloverScene.plan, action: CloverAction.balconyWater, ambience: AmbienceKind.petals), line, const Alignment(-.5, -.5));
      case _Step.pace:
        final i = _paces.indexWhere((p) => p.$1 == _pace);
        return (
          StageSpec.room(CloverScene.march, walking: true, ambience: AmbienceKind.leaves, speed: const [.55, 1.0, 1.9][i]),
          _paces[i].$3,
          const Alignment(.45, -.5),
        );
      case _Step.body:
        return (const StageSpec.room(CloverScene.gym, action: CloverAction.gymJacks, ambience: AmbienceKind.sparkles), _limitsLine(), const Alignment(-.55, -.55));
      case _Step.reminders:
        final night = _skyAt < 6 * 60 || _skyAt >= 19 * 60;
        final sky = DateTime(2026, 1, 1, _skyAt ~/ 60, _skyAt % 60);
        return (
          StageSpec.room(
            CloverScene.profile,
            action: CloverAction.bedroomTidy,
            ambience: night ? AmbienceKind.fireflies : AmbienceKind.dust,
            overlay: ProviderScope(overrides: [clockProvider.overrideWithValue(() => sky)], child: const BedroomWindow()),
          ),
          null,
          Alignment.center,
        );
      case _Step.building:
        return (
          const StageSpec.room(CloverScene.progress, action: CloverAction.hallGaze2, ambience: AmbienceKind.dust),
          you.isEmpty ? 'Hang on. I’m drawing our road…' : 'Hang on, $you. I’m drawing our road…',
          const Alignment(.7, .25),
        );
      case _Step.journey:
        return (
          const StageSpec.room(CloverScene.cheer, cheering: true, ambience: AmbienceKind.confetti),
          you.isEmpty ? 'Look! This is OUR road.' : '$you, look! This is OUR road.',
          const Alignment(-.65, -.6),
        );
    }
  }

  /// Her sample nudge, sliding in on the bedroom page: what a morning from her will look like.
  Widget _nudgePreview() {
    final morning = _skyAt < 15 * 60;
    final when = clockText(morning ? _morningAt : _eveningAt);
    final text = morning
        ? 'Morning${_you.isEmpty ? '' : ', $_you'}! ${_paces.firstWhere((p) => p.$1 == _pace).$2} walk first?${_easy.contains('knees') ? ' Easy on the knees, promise.' : ''}'
        : 'How did today go${_you.isEmpty ? '' : ', $_you'}? I’m on the sofa if you want to tell me.';
    return Positioned(
      left: 16,
      right: 16,
      bottom: 64,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(morning),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: BloomMotion.spring,
        builder: (context, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: BloomColors.surface.withValues(alpha: .97),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x332E3826), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/cats/thumb-clover.png', width: 40, height: 40, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(_catName, style: BloomText.headline.copyWith(fontSize: 15))), Text(when, style: BloomText.caption)]),
                Text(text, style: BloomText.body.copyWith(fontSize: 14, height: 20 / 14)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step.index > 0 && _step != _Step.paywall && _step != _Step.building) _back();
      },
      child: Scaffold(
        backgroundColor: BloomColors.paper,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: BloomMotion.enter,
          switchOutCurve: BloomMotion.leave,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(a), child: c)),
          child: _step == _Step.paywall ? KeyedSubtree(key: const ValueKey('paywall'), child: PaywallScreen(onDone: _finish)) : KeyedSubtree(key: const ValueKey('house'), child: _house()),
        ),
      ),
    );
  }

  /// Every page before Plus: the live stage on top, the page's card sliding underneath.
  Widget _house() {
    final mq = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      final typing = mq.viewInsets.bottom > 0;
      final target = typing
          ? h * .3
          : switch (_step) {
              _Step.welcome => h * .6,
              _Step.journey || _Step.building => h * .44,
              _Step.numbers || _Step.body => h * .38,
              _ => h * .47,
            };
      final (spec, line, lineAt) = _stage();
      return TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: const Duration(milliseconds: 640),
        curve: Curves.easeOutCubic,
        builder: (context, stageH, _) => Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ObStage(
              key: _stageKey,
              spec: spec,
              height: stageH + 40,
              line: _quip ?? line,
              lineAt: lineAt,
              onTapClover: _step == _Step.welcome ? null : _tickle,
              extra: _step == _Step.reminders ? _nudgePreview() : null,
            ),
          ),
          if (_step != _Step.welcome)
            Positioned(
              left: 12,
              right: 16,
              top: mq.padding.top + 8,
              child: _TopBar(
                step: (_step.index - 1).clamp(0, 8),
                total: 8,
                onBack: _step == _Step.building ? null : _back,
              ),
            ),
          Positioned(left: 0, right: 0, top: stageH - 8, bottom: 0, child: _sheet()),
        ]),
      );
    });
  }

  Widget _sheet() {
    final mq = MediaQuery.of(context);
    final (content, cta, ghost) = _page();
    return Container(
      decoration: const BoxDecoration(
        color: BloomColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(BloomSpace.rXl)),
        boxShadow: [BoxShadow(color: Color(0x1F2E3826), blurRadius: 32, offset: Offset(0, -10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 460),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
        transitionBuilder: (c, a) {
          final incoming = c.key == ValueKey(_step);
          final dx = (incoming ? 1 : -1) * (_forward ? 1 : -1) * .22;
          return FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: c),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: Column(children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                children: [
                  for (var i = 0; i < content.length; i++) ...[
                    RiseIn(delay: BloomMotion.stagger * (i + 2), child: content[i]),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, (ghost == null ? 16 : 4) + mq.padding.bottom),
              child: Column(children: [?cta, ?ghost]),
            ),
          ]),
        ),
      ),
    );
  }

  (List<Widget>, Widget?, Widget?) _page() {
    Widget next({bool enabled = true, String label = 'Next'}) => LedgeButton(label: label, onPressed: enabled ? _next : null);
    final you = _you;
    switch (_step) {
      case _Step.welcome:
        return (
          [
            Column(children: [
              Text('WELCOME HOME', style: BloomText.label),
              const SizedBox(height: 6),
              Text('Meet Clover', style: BloomText.displayXl),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text('A little cat with a big plan: get moving again. She only does it with you.', style: BloomText.bodyMuted, textAlign: TextAlign.center),
              ),
            ]),
          ],
          LedgeButton(label: 'Let’s meet her', glow: true, onPressed: _next),
          null,
        );
      case _Step.catName:
        return (
          [
            const ObQuestion('What will you call her?', help: 'Clover is her name until you pick another.'),
            Row(children: [
              Expanded(child: _NameField(controller: _cat, hint: 'Her name', onChanged: () => setState(() {}), onDone: _cat.text.trim().isEmpty ? null : _next)),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Shuffle names',
                child: GestureDetector(
                  onTap: _shuffleCat,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: BloomColors.paperSunk,
                      borderRadius: BorderRadius.circular(BloomSpace.rMd),
                      boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 3))],
                    ),
                    child: const Icon(Icons.shuffle_rounded, color: BloomColors.ink),
                  ),
                ),
              ),
            ]),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final n in _catNames.take(6))
                _Pill(
                  label: n,
                  selected: _catName == n,
                  onTap: (at) {
                    _cat.text = n;
                    _sparkle(at);
                    setState(() {});
                  },
                ),
            ]),
          ],
          next(enabled: _cat.text.trim().isNotEmpty, label: 'That’s her name'),
          null,
        );
      case _Step.name:
        return (
          [
            ObQuestion('What should $_catName call you?', help: 'Just a first name is perfect.'),
            _NameField(controller: _name, hint: 'Your name', onChanged: () => setState(() {}), onDone: you.isEmpty ? null : _meetYou),
          ],
          LedgeButton(label: 'Nice to meet you', onPressed: you.isEmpty ? null : _meetYou),
          null,
        );
      case _Step.why:
        return (
          [
            ObQuestion(you.isEmpty ? 'What brings you here?' : 'What brings you here, $you?', help: 'Pick the main one. You can change it later.'),
            for (final MapEntry(key: r, value: (_, icon, act)) in _reasons.entries)
              _Tapped(
                onTap: (at) {
                  setState(() => _reason = r);
                  _sparkle(at);
                  _act(act);
                },
                child: ObChoice(
                  label: r,
                  selected: _reason == r,
                  leading: Image.asset('assets/plan/$icon.webp', width: 40, height: 40),
                  onTap: () {},
                ),
              ),
          ],
          next(enabled: _reason != null, label: 'That’s me'),
          null,
        );
      case _Step.numbers:
        final u = _units;
        final diff = _kg - _goal;
        return (
          [
            ObQuestion(you.isEmpty ? 'Where are we starting?' : 'Where are we starting, $you?', help: 'Only you see this. It sets a safe pace for both of you.'),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 180, child: SegmentedSwitch(labels: const ['kg', 'lb'], index: _pounds ? 1 : 0, onChanged: (i) => setState(() => _pounds = i == 1))),
            ),
            BloomCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Eyebrow('Today’s weight'),
                WeightStepper(kg: _kg, units: u, label: 'Today’s weight', onChanged: (v) => setState(() => _kg = v)),
                const Divider(color: BloomColors.line, height: 24),
                const Eyebrow('Goal weight'),
                WeightStepper(
                  kg: _goal,
                  units: u,
                  label: 'Goal weight',
                  onChanged: (v) {
                    // Each step down waters her lavender a little more.
                    if (v < _goal) FxLayer.burst(_stageAt(.3, .55), count: 6, power: .25);
                    setState(() => _goal = v);
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  diff > .05 ? 'That’s ${u.short(diff)} to go. $_catName will pace it gently.' : 'Pick a goal a little below where you are, or keep it the same to just stay active.',
                  style: BloomText.caption.copyWith(fontSize: 14),
                ),
              ]),
            ),
          ],
          next(),
          null,
        );
      case _Step.pace:
        return (
          [
            ObQuestion('How fast should we go?', help: 'We never plan faster than ${_units.short(1)} a week.'),
            for (final (kg, word, _) in _paces)
              _Tapped(
                onTap: (at) {
                  setState(() => _pace = kg);
                  _sparkle(at, count: 8);
                },
                child: ObChoice(
                  label: '$word · ${_units.short(kg)} a week',
                  sub: kg == .7 ? 'Her favourite' : null,
                  selected: _pace == kg,
                  trailing: _goalDate(kg) == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(left: 8, right: 4),
                          child: Text(shortDate(_goalDate(kg)!), style: BloomText.headline.copyWith(fontSize: 15, color: _pace == kg ? BloomColors.forest : BloomColors.ink)),
                        ),
                  onTap: () {},
                ),
              ),
          ],
          next(label: '${_paces.firstWhere((p) => p.$1 == _pace).$2} it is'),
          null,
        );
      case _Step.body:
        return (
          [
            const ObQuestion('Your body today', help: 'She picks every move around it.'),
            Text('ON A NORMAL DAY', style: BloomText.label),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in _activities.keys)
                _Pill(
                  label: a,
                  selected: _activity == a,
                  onTap: (at) {
                    _sparkle(at, count: 8);
                    setState(() => _activity = a);
                  },
                ),
            ]),
            Text('${_catName.toUpperCase()} GOES EASY ON', style: BloomText.label),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _limits.entries)
                _Pill(
                  label: e.value,
                  tick: true,
                  selected: _easy.contains(e.key),
                  onTap: (at) {
                    _sparkle(at, count: 8);
                    setState(() {
                      _noLimits = false;
                      _easy.contains(e.key) ? _easy.remove(e.key) : _easy.add(e.key);
                    });
                  },
                ),
              _Pill(
                label: 'Nothing, I’m good',
                tick: true,
                selected: _noLimits,
                onTap: (at) {
                  _sparkle(at, count: 8);
                  setState(() {
                    _noLimits = !_noLimits;
                    if (_noLimits) _easy.clear();
                  });
                },
              ),
            ]),
          ],
          next(enabled: _activity != null && (_noLimits || _easy.isNotEmpty)),
          null,
        );
      case _Step.reminders:
        return (
          [
            ObQuestion('When should $_catName nudge you?', help: 'Tap a time to change it. Her window shows the sky.'),
            _ReminderRow(
              title: 'Morning',
              caption: 'A look at today’s plan',
              on: _morning,
              at: _morningAt,
              onToggle: (v) => setState(() {
                _morning = v;
                _skyAt = _morningAt;
              }),
              onTime: (m) => setState(() => _morningAt = _skyAt = m),
            ),
            _ReminderRow(
              title: 'Evening',
              caption: 'How did today go?',
              on: _evening,
              at: _eveningAt,
              onToggle: (v) => setState(() {
                _evening = v;
                _skyAt = _eveningAt;
              }),
              onTime: (m) => setState(() => _eveningAt = _skyAt = m),
            ),
          ],
          LedgeButton(label: _morning || _evening ? 'Turn on her nudges' : 'Next', onPressed: _morning || _evening ? _turnOnReminders : _next),
          LedgeButton(
            label: 'Maybe later',
            variant: LedgeVariant.ghost,
            onPressed: () {
              setState(() => _morning = _evening = false);
              _next();
            },
          ),
        );
      case _Step.building:
        final u = _units;
        final rows = [
          _reason ?? 'Moving together',
          '${u.short(_kg).split(' ').first} to ${u.short(_goal)}',
          'A ${_paces.firstWhere((p) => p.$1 == _pace).$2.toLowerCase()} ${u.short(_pace)} a week',
          _easy.isEmpty ? 'Every move on the table' : 'Moves that are kind to your ${_list(_easy.map((k) => _limits[k]!.toLowerCase()).toList())}',
          _morning || _evening ? 'Nudges at ${[if (_morning) clockText(_morningAt), if (_evening) clockText(_eveningAt)].join(' and ')}' : 'No nudges, just her',
        ];
        return (
          [
            Text('PUTTING IT TOGETHER', style: BloomText.label),
            Text(you.isEmpty ? 'Just a moment' : 'Just a moment, $you', style: BloomText.display.copyWith(fontSize: 27, height: 33 / 27)),
            for (var i = 0; i < rows.length; i++) _CheckIn(label: rows[i], state: i < _ticks ? 2 : (i == _ticks ? 1 : 0)),
          ],
          TweenAnimationBuilder<double>(
            tween: Tween(end: _ticks / 5),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: v, minHeight: 10, backgroundColor: BloomColors.paperSunk, color: BloomColors.forest),
            ),
          ),
          null,
        );
      case _Step.journey:
        final today = dayKey(DateTime.now());
        final u = _units;
        final when = _goalDate(_pace);
        return (
          [
            Text('BASED ON EVERYTHING YOU TOLD HER', style: BloomText.label),
            Text(when == null ? 'Moving every day' : '${u.short(_goal)} by ${shortDate(when)}', style: BloomText.displayXl.copyWith(fontSize: 36, height: 42 / 36)),
            BloomCard(child: JourneyTrack(journal: Journal(start: today, today: today))),
            Row(children: [
              const Expanded(child: StatCard(value: '3 moves', label: 'A day')),
              const SizedBox(width: 10),
              const Expanded(child: StatCard(value: '~15 min', label: 'Together')),
              const SizedBox(width: 10),
              Expanded(child: StatCard(value: _easy.isEmpty ? 'All moves' : 'Gentle', label: _easy.isEmpty ? 'On the table' : 'On ${_limits[_easy.first]!.toLowerCase()}')),
            ]),
          ],
          KeyedSubtree(key: _startKey, child: LedgeButton(label: 'Start our journey', glow: true, onPressed: _start)),
          null,
        );
      case _Step.paywall:
        return (const [], null, null);
    }
  }

  String _list(List<String> xs, {bool capital = false}) {
    final s = xs.length == 1 ? xs.first : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';
    return capital && s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
  }
}

/// The back button and step bar, floating over the stage.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, required this.total, required this.onBack});
  final int step, total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(children: [
        AnimatedOpacity(
          duration: BloomMotion.base,
          opacity: onBack == null ? 0 : 1,
          child: Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Color(0xEEFFFBF3), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1F2E3826), blurRadius: 10, offset: Offset(0, 3))]),
                child: const Icon(Icons.chevron_left_rounded, size: 30, color: BloomColors.ink),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            label: 'Step $step of $total',
            child: Container(
              height: 10,
              decoration: BoxDecoration(color: const Color(0xCCFFFBF3), borderRadius: BorderRadius.circular(6)),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: step / total),
                duration: const Duration(milliseconds: 620),
                curve: BloomMotion.spring,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v.clamp(0.0, 1.0),
                  child: Container(decoration: BoxDecoration(color: BloomColors.forest, borderRadius: BorderRadius.circular(6))),
                ),
              ),
            ),
          ),
        ),
      ]);
}

/// Hands the global tap position to [onTap] (for sparkles where the finger landed).
class _Tapped extends StatelessWidget {
  const _Tapped({required this.onTap, required this.child});
  final void Function(Offset global) onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          Feel.selectionClick();
          onTap(d.globalPosition);
        },
        child: IgnorePointer(child: child),
      );
}

/// A pill to pick (a name, an activity, a joint), springing when picked.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap, this.tick = false});
  final String label;
  final bool selected, tick;
  final void Function(Offset global) onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTapUp: (d) {
            Feel.selectionClick();
            onTap(d.globalPosition);
          },
          child: TweenAnimationBuilder<double>(
            key: ValueKey(selected),
            tween: Tween(begin: selected ? .9 : 1, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: BloomMotion.pop,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: AnimatedContainer(
              duration: BloomMotion.base,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? BloomColors.forestSoft : BloomColors.surface,
                borderRadius: BorderRadius.circular(BloomSpace.rPill),
                border: Border.all(color: selected ? BloomColors.forest : BloomColors.line, width: 2),
                boxShadow: [BoxShadow(color: selected ? BloomColors.sage : BloomColors.line, offset: const Offset(0, 3))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (tick && selected) ...[const Icon(Icons.check_rounded, size: 18, color: BloomColors.forest), const SizedBox(width: 4)],
                Text(label, style: BloomText.headline.copyWith(fontSize: 15, color: selected ? BloomColors.forest : BloomColors.ink)),
              ]),
            ),
          ),
        ),
      );
}

/// One answer checking in while she draws the road: waiting, in progress, then ticked with a pop.
class _CheckIn extends StatelessWidget {
  const _CheckIn({required this.label, required this.state});
  final String label;
  final int state; // 0 waiting, 1 now, 2 done

  @override
  Widget build(BuildContext context) => Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: BloomMotion.pop,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == 2 ? BloomColors.forest : BloomColors.surface,
            border: Border.all(color: state == 2 ? BloomColors.forest : (state == 1 ? BloomColors.mustard : BloomColors.line), width: state == 1 ? 3 : 2),
          ),
          child: AnimatedScale(
            scale: state == 2 ? 1 : 0,
            duration: const Duration(milliseconds: 360),
            curve: BloomMotion.pop,
            child: const Icon(Icons.check_rounded, size: 18, color: BloomColors.onForest),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: BloomMotion.base,
            style: BloomText.headline.copyWith(fontSize: 16, color: state == 0 ? BloomColors.inkMuted : BloomColors.ink),
            child: Text(label),
          ),
        ),
      ]);
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.hint, required this.onChanged, required this.onDone});
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onDone?.call(),
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        style: BloomText.title,
        cursorColor: BloomColors.forest,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BloomText.title.copyWith(color: BloomColors.inkMuted, fontWeight: FontWeight.w700),
          filled: true,
          fillColor: BloomColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.lineStrong, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.forest, width: 2)),
        ),
      );
}

/// A reminder: toggle plus a tappable time.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.title, required this.caption, required this.on, required this.at, required this.onToggle, required this.onTime});
  final String title, caption;
  final bool on;
  final int at;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onTime;

  @override
  Widget build(BuildContext context) => BloomCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('$title · ', style: BloomText.headline.copyWith(fontSize: 16)),
                GestureDetector(
                  onTap: () => pickTime(context, at, onTime),
                  child: Text(clockText(at), style: BloomText.headline.copyWith(fontSize: 16, color: BloomColors.forest, decoration: TextDecoration.underline, decorationColor: BloomColors.sage)),
                ),
              ]),
              Text(caption, style: BloomText.caption),
            ]),
          ),
          BloomToggle(label: '$title reminder', value: on, onChanged: onToggle),
        ]),
      );
}

/// The system time picker in Bloom's colours.
Future<void> pickTime(BuildContext context, int minutes, ValueChanged<int> onPicked) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    builder: (c, child) => Theme(
      data: Theme.of(c).copyWith(
        colorScheme: Theme.of(c).colorScheme.copyWith(primary: BloomColors.forest, surface: BloomColors.surface, onSurface: BloomColors.ink),
        timePickerTheme: const TimePickerThemeData(backgroundColor: BloomColors.surface),
      ),
      child: child!,
    ),
  );
  if (t != null) onPicked(t.hour * 60 + t.minute);
}
