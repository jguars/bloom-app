import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/reminders.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/profile.dart';
import '../../data/today.dart';
import '../../data/weight.dart';
import '../../ui/bits.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/room_frame.dart';
import '../../ui/scene.dart';
import '../../ui/weight_chart.dart';
import '../paywall/paywall_screen.dart';
import '../progress/journey.dart';
import '../progress/weight_sheet.dart';
import 'ob_widgets.dart';

enum _Step { welcome, name, why, numbers, pace, activity, limits, reminders, journey, paywall }

const _reasons = {
  'Lose some weight': 'Me too! We’ll do it gently.',
  'Move more every day': 'Ooh, let’s get these paws moving!',
  'Feel lighter and calmer': 'Deep breaths and short walks. I’m in.',
  'Build better habits': 'Little habits, big bloom!',
};

const _paces = [
  (0.5, 'Gentle', 'Nice and easy. I like it.'),
  (0.7, 'Steady', 'Steady it is! My favourite.'),
  (1.0, 'Brisk', 'Ooh, brisk! I’ll stretch first.'),
];

const _activities = {
  'Mostly sitting': 'Same! We’ll start light.',
  'Some walking': 'Good base! Let’s build on it.',
  'On my feet a lot': 'Wow! You’ll outpace me.',
  'Not sure': 'No problem. We’ll find out together.',
};

const _limits = {'knees': 'Knees', 'back': 'Back', 'wrists': 'Wrists', 'shoulders': 'Shoulders'};

/// The first run: meet Clover, a few questions, the journey, then Plus.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  var _step = _Step.welcome;
  var _forward = true;

  // Answers.
  final _name = TextEditingController();
  String? _reason, _activity;
  bool _pounds = false;
  double _kg = 80, _goal = 74, _pace = .7;
  final Set<String> _easy = {};
  bool _noLimits = false;
  bool _morning = true, _evening = true;
  int _morningAt = 8 * 60, _eveningAt = 20 * 60 + 30;
  final _startKey = GlobalKey();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _go(_Step s) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = s.index > _step.index;
      _step = s;
    });
  }

  void _next() => _go(_Step.values[_step.index + 1]);
  void _back() => _go(_Step.values[_step.index - 1]);

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
          name: _name.text.trim(),
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

  void _finish() => ref.read(profileProvider.notifier).update(ref.read(profileProvider).copyWith(onboarded: true));

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      _Step.welcome => _welcome(),
      _Step.paywall => PaywallScreen(onDone: _finish),
      _ => _question(),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step.index > 0 && _step != _Step.paywall) _back();
      },
      child: Scaffold(
        backgroundColor: _step == _Step.welcome || _step == _Step.paywall ? BloomColors.surface : BloomColors.paper,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: BloomMotion.enter,
          switchOutCurve: BloomMotion.leave,
          transitionBuilder: (c, a) {
            final incoming = c.key == ValueKey(_step);
            final dx = (incoming ? 1 : -1) * (_forward ? 1 : -1) * .12;
            return FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: c),
            );
          },
          child: KeyedSubtree(key: ValueKey(_step), child: body),
        ),
      ),
    );
  }

  Widget _welcome() {
    final mq = MediaQuery.of(context);
    final sceneH = mq.size.height * .6;
    return Stack(fit: StackFit.expand, children: [
      Positioned(left: 0, right: 0, top: 0, child: Scene(asset: 'assets/scenes/porch.jpg', height: sceneH, fadeHeight: 110, alignment: const Alignment(0, -.25))),
      Positioned(
        left: 24,
        right: 24,
        top: sceneH - 24,
        bottom: 24 + mq.padding.bottom,
        child: Column(children: [
          RiseIn(delay: const Duration(milliseconds: 200), child: Text('WELCOME HOME', style: BloomText.label)),
          const SizedBox(height: 6),
          RiseIn(delay: const Duration(milliseconds: 280), child: Text('Meet Clover', style: BloomText.displayXl)),
          const SizedBox(height: 8),
          RiseIn(
            delay: const Duration(milliseconds: 360),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text('A little cat with a big plan: get moving again. She only does it with you.', style: BloomText.bodyMuted, textAlign: TextAlign.center),
            ),
          ),
          const Spacer(),
          RiseIn(delay: const Duration(milliseconds: 480), child: LedgeButton(label: 'Let’s meet her', glow: true, onPressed: _next)),
        ]),
      ),
    ]);
  }

  Widget _question() {
    final mq = MediaQuery.of(context);
    final (content, cta, ghost) = _stepContent();
    return Padding(
      padding: EdgeInsets.fromLTRB(8, mq.padding.top + 4, 0, 0),
      child: Column(children: [
        ObTopBar(step: _step.index, total: _Step.values.length - 2, onBack: _back),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 20, 20, 20),
            children: [
              for (var i = 0; i < content.length; i++) ...[
                RiseIn(delay: BloomMotion.stagger * (i + 1), child: content[i]),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 20, (ghost == null ? 16 : 4) + mq.padding.bottom),
          child: Column(children: [cta, ?ghost]),
        ),
      ]),
    );
  }

  (List<Widget>, Widget, Widget?) _stepContent() {
    Widget next({bool enabled = true, String label = 'Next'}) => LedgeButton(label: label, onPressed: enabled ? _next : null);
    switch (_step) {
      case _Step.name:
        final n = _name.text.trim();
        return (
          [
            CloverSays(scene: 'porch', line: n.isEmpty ? 'Hi! I’m Clover. And you are…?' : 'Hi, $n! Love that name.'),
            const ObQuestion('What should Clover call you?', help: 'Just a first name is perfect.'),
            _NameField(controller: _name, onChanged: () => setState(() {}), onDone: n.isEmpty ? null : _next),
          ],
          next(enabled: n.isNotEmpty),
          null,
        );
      case _Step.why:
        return (
          [
            CloverSays(line: _reason == null ? 'Ooh, tell me everything.' : _reasons[_reason]!),
            const ObQuestion('What brings you here?', help: 'Pick the main one. You can change it later.'),
            for (final r in _reasons.keys) ObChoice(label: r, selected: _reason == r, onTap: () => setState(() => _reason = r)),
          ],
          next(enabled: _reason != null),
          null,
        );
      case _Step.numbers:
        final u = _units;
        final diff = _kg - _goal;
        return (
          [
            const ObQuestion('Where are we starting?', help: 'Only you see this. It sets a safe pace for both of you.'),
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
                WeightStepper(kg: _goal, units: u, label: 'Goal weight', onChanged: (v) => setState(() => _goal = v)),
                const SizedBox(height: 6),
                Text(
                  diff > .05 ? 'That’s ${u.short(diff)} to go. Clover will pace it gently.' : 'Pick a goal a little below where you are, or keep it the same to just stay active.',
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
            CloverSays(line: _paces.firstWhere((p) => p.$1 == _pace).$3),
            ObQuestion('How fast should we go?', help: 'We never plan faster than ${_units.short(1)} a week.'),
            for (final (kg, word, _) in _paces)
              ObChoice(
                label: '$word · ${_units.short(kg)} a week',
                sub: [if (kg == .7) 'Recommended', if (_goalDate(kg) != null) 'Goal around ${shortDate(_goalDate(kg)!)}'].join(' · '),
                selected: _pace == kg,
                onTap: () => setState(() => _pace = kg),
              ),
          ],
          next(),
          null,
        );
      case _Step.activity:
        return (
          [
            CloverSays(line: _activity == null ? 'Be honest, I won’t judge!' : _activities[_activity]!),
            const ObQuestion('How active are you on a normal day?', help: 'It helps Clover pick moves at the right effort.'),
            for (final a in _activities.keys) ObChoice(label: a, selected: _activity == a, onTap: () => setState(() => _activity = a)),
          ],
          next(enabled: _activity != null),
          null,
        );
      case _Step.limits:
        final picked = _easy.map((k) => _limits[k]!.toLowerCase()).toList();
        final line = _noLimits
            ? 'Great! All moves are on the table.'
            : picked.isEmpty
                ? 'Anything sore? Tell me.'
                : 'Got it. I’ll go easy on your ${_list(picked)}.';
        return (
          [
            CloverSays(line: line),
            const ObQuestion('Anything Clover should go easy on?', help: 'Pick any that fit. She’ll skip moves that strain them.'),
            for (final e in _limits.entries)
              ObChoice(
                label: e.value,
                multi: true,
                selected: _easy.contains(e.key),
                onTap: () => setState(() {
                  _noLimits = false;
                  _easy.contains(e.key) ? _easy.remove(e.key) : _easy.add(e.key);
                }),
              ),
            ObChoice(
              label: 'None of these',
              multi: true,
              selected: _noLimits,
              onTap: () => setState(() {
                _noLimits = !_noLimits;
                if (_noLimits) _easy.clear();
              }),
            ),
          ],
          next(enabled: _noLimits || _easy.isNotEmpty),
          null,
        );
      case _Step.reminders:
        return (
          [
            const CloverSays(line: 'I’ll tap on the window. Gently.'),
            const ObQuestion('When should Clover nudge you?', help: 'Tap a time to change it.'),
            _ReminderRow(title: 'Morning', caption: 'A look at today’s plan', on: _morning, at: _morningAt, onToggle: (v) => setState(() => _morning = v), onTime: (m) => setState(() => _morningAt = m)),
            _ReminderRow(title: 'Evening', caption: 'How did today go?', on: _evening, at: _eveningAt, onToggle: (v) => setState(() => _evening = v), onTime: (m) => setState(() => _eveningAt = m)),
          ],
          LedgeButton(label: _morning || _evening ? 'Turn on reminders' : 'Next', onPressed: _morning || _evening ? _turnOnReminders : _next),
          LedgeButton(
            label: 'Maybe later',
            variant: LedgeVariant.ghost,
            onPressed: () {
              setState(() => _morning = _evening = false);
              _next();
            },
          ),
        );
      case _Step.journey:
        final today = dayKey(DateTime.now());
        final u = _units;
        return (
          [
            const CloverSays(scene: 'hall', line: 'This is our road. Ready when you are!'),
            const ObQuestion('Your journey with Clover', help: 'Every move you make together brings the next flag closer.'),
            BloomCard(child: JourneyTrack(journal: Journal(start: today, today: today))),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.1,
              children: [
                StatCard(value: '${u.short(_kg).split(' ').first} to ${u.short(_goal)}', label: 'Start and goal'),
                StatCard(value: u.short(_pace), label: 'A week'),
                const StatCard(value: '3 moves', label: 'A day'),
                const StatCard(value: '~15 min', label: 'Together daily'),
              ],
            ),
          ],
          KeyedSubtree(key: _startKey, child: LedgeButton(label: 'Start our journey', glow: true, onPressed: _start)),
          null,
        );
      case _Step.welcome || _Step.paywall:
        throw StateError('not a question');
    }
  }

  String _list(List<String> xs) => xs.length == 1 ? xs.first : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onChanged, required this.onDone});
  final TextEditingController controller;
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
          hintText: 'Your name',
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
