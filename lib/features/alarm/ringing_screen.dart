import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/alarms.dart';
import '../../data/exercises.dart';
import '../../data/profile.dart';
import '../../data/today.dart';
import '../../ui/clover_rive.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/speech_bubble.dart';

/// Full-screen wake-up: a sky that brightens from dawn to morning while
/// Clover stretches. "I'm up" puts a morning stretch next on Today.
class RingingScreen extends ConsumerStatefulWidget {
  const RingingScreen({super.key, required this.alarmId});
  final int alarmId;

  @override
  ConsumerState<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends ConsumerState<RingingScreen> with SingleTickerProviderStateMixin {
  late final _sky = AnimationController(vsync: this, duration: const Duration(seconds: 20))..forward();

  @override
  void dispose() {
    _sky.dispose();
    super.dispose();
  }

  Future<void> _wake() async {
    Feel.heavyImpact();
    await ref.read(alarmsProvider.notifier).dismissed(widget.alarmId);
    final stretch = exerciseById('stretch');
    if (stretch != null) ref.read(todayProvider.notifier).pickExercise(stretch);
    ref.read(roomProvider.notifier).go(Room.today);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    Feel.mediumImpact();
    await ref.read(alarmsProvider.notifier).snooze(widget.alarmId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final alarm = ref.read(alarmsProvider.notifier).byId(widget.alarmId);
    final name = ref.watch(profileProvider).name.trim();
    final now = TimeOfDay.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final mq = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _sky,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_sky.value);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                  Color.lerp(const Color(0xFF2B3F66), BloomColors.sky, t)!,
                  Color.lerp(const Color(0xFFE79A84), BloomColors.mustardSoft, t)!,
                  BloomColors.paper,
                ], stops: const [0, .55, 1]),
              ),
              child: child,
            );
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, mq.padding.top + 40, 20, 20 + mq.padding.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PopIn(child: Text(time, textAlign: TextAlign.center, style: BloomText.displayXl.copyWith(fontSize: 72, color: BloomColors.surface, fontFeatures: const [FontFeature.tabularFigures()]))),
              Text(alarm?.label.isNotEmpty == true ? alarm!.label : 'Good morning${name.isEmpty ? '' : ', $name'}!', textAlign: TextAlign.center, style: BloomText.title.copyWith(color: BloomColors.surface)),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerRight, child: SpeechBubble(text: 'Stretch with me? Arms up!', tailRight: true)),
              const Expanded(child: LiveClover(action: CloverAction.reach)),
              LedgeButton(label: 'I’m up!', glow: true, onPressed: _wake),
              const SizedBox(height: 8),
              LedgeButton(label: 'Snooze ${kSnooze.inMinutes} min', variant: LedgeVariant.secondary, onPressed: _snooze),
            ]),
          ),
        ),
      ),
    );
  }
}
