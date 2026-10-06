import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercises.dart';
import '../data/today.dart';
import '../features/today/celebration_screen.dart';
import '../features/today/ready_screen.dart';
import '../features/today/session_screen.dart';
import '../features/urge/urge_screen.dart';
import 'perf_probe.dart';
import 'shell.dart';

/// Opens the heavy screens on a timer so [PerfProbe] can measure them without
/// anyone tapping (MIUI blocks injected input). Only in builds made with
/// `--dart-define=PERF=true --dart-define=PERF_TOUR=true`.
class PerfTour {
  static const enabled = PerfProbe.enabled && bool.fromEnvironment('PERF_TOUR');

  static Future<void> run(GlobalKey<NavigatorState> nav, WidgetRef ref) async {
    if (!enabled) return;
    Future<void> wait(int s) => Future<void>.delayed(Duration(seconds: s));
    Future<void> visit(String name, Widget screen, int seconds) async {
      debugPrint('[perf] tour: $name');
      nav.currentState?.push(MaterialPageRoute<void>(builder: (_) => screen, settings: RouteSettings(name: name)));
      await wait(seconds);
      nav.currentState?.pop();
      await wait(3);
    }

    await wait(6);
    debugPrint('[perf] tour: today idle');
    await wait(4);
    for (final r in [Room.shop, Room.plan, Room.progress, Room.profile, Room.today]) {
      PerfProbe.tab(r.name);
      ref.read(roomProvider.notifier).go(r);
      await wait(3);
    }
    final march = dailyExercises.firstWhere((e) => e.id == 'march');
    final squats = dailyExercises.firstWhere((e) => e.id == 'squats');
    await visit('ready', ReadyScreen(ex: march), 6);
    await visit('session-march', SessionScreen(ex: march), 12);
    await visit('session-squat', SessionScreen(ex: squats), 10);
    await visit('urge', const UrgeScreen(), 8);
    await visit('celebration', CelebrationScreen(ex: march, reward: const Reward(paws: 10, bonus: 0, doneNow: 2)), 8);
    debugPrint('[perf] tour: done');
  }
}
