import 'package:flutter/material.dart';

import '../data/exercises.dart';
import '../features/today/session_screen.dart';

/// Debug: `--dart-define=MOVE_TOUR=squats,dance` opens a session for each move in turn (12 s each, from 4 s after
/// launch), for checking Clover's moves on a device without tapping through.
class MoveTour {
  static const ids = String.fromEnvironment('MOVE_TOUR');

  static Future<void> run(GlobalKey<NavigatorState> nav) async {
    if (ids.isEmpty) return;
    await Future<void>.delayed(const Duration(seconds: 4));
    for (final id in ids.split(',')) {
      final ex = exerciseById(id);
      final n = nav.currentState;
      if (ex == null || n == null) continue;
      n.push(MaterialPageRoute<void>(builder: (_) => SessionScreen(ex: ex)));
      await Future<void>.delayed(const Duration(seconds: 12));
      nav.currentState?.pop();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }
}
