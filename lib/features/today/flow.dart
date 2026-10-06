import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../data/today.dart';

/// Page transition for the Today loop: the next screen rises and settles with
/// a little overshoot while the old one fades.
Route<T> bloomRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: BloomMotion.spring, reverseCurve: BloomMotion.leave);
        return FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: const Interval(0, .6)),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(c),
            child: ScaleTransition(scale: Tween(begin: .985, end: 1.0).animate(c), child: child),
          ),
        );
      },
    );

/// A reward the celebration has handed back to Today, which then flies the
/// paws into the balance. Cleared once Today has played it.
final pendingRewardProvider = NotifierProvider<PendingReward, Reward?>(PendingReward.new);

class PendingReward extends Notifier<Reward?> {
  @override
  Reward? build() => null;
  void set(Reward? r) => state = r;
}

/// Asks Today to open the evening check-in (e.g. from the evening reminder).
final checkInRequestProvider = NotifierProvider<CheckInRequest, int>(CheckInRequest.new);

class CheckInRequest extends Notifier<int> {
  @override
  int build() => 0;
  void ask() => state++;
}
