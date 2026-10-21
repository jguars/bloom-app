import 'package:bloom/data/journal.dart';
import 'package:bloom/data/streak.dart';
import 'package:bloom/data/today.dart';
import 'package:flutter_test/flutter_test.dart';

/// A journal starting [start] days before [today], with moves on the given days back from today (0 = today).
Journal journal(List<int> movedDaysAgo, {int start = 30}) {
  final today = DateTime(2026, 10, 9);
  return Journal(
    start: dayKey(today.subtract(Duration(days: start))),
    today: dayKey(today),
    days: {for (final n in movedDaysAgo) dayKey(today.subtract(Duration(days: n))): const DayLog(moves: 1)},
    loaded: true,
  );
}

void main() {
  test('counts days in a row, today included once it has a move', () {
    expect(Streak.of(journal([0, 1, 2, 3]), const StreakState()).current, 4);
    expect(Streak.of(journal([0, 1, 2, 3]), const StreakState()).doneToday, isTrue);
  });

  test('today without a move yet keeps the run up to yesterday alive', () {
    final s = Streak.of(journal([1, 2, 3]), const StreakState());
    expect(s.current, 3);
    expect(s.doneToday, isFalse);
    expect(s.gap, isNull);
  });

  test('a missed yesterday after a run is offered as a gap the patches can cover', () {
    final s = Streak.of(journal([2, 3, 4, 5]), const StreakState(patches: 1));
    expect(s.current, 0);
    expect(s.gap, isNotNull);
    expect(s.gap!.days, 1);
    expect(s.gap!.run, 4);
  });

  test('no gap offered without enough patches, for a one-day run, or once declined', () {
    expect(Streak.of(journal([3, 4, 5]), const StreakState(patches: 1)).gap, isNull, reason: 'two missed days, one patch');
    expect(Streak.of(journal([2]), const StreakState(patches: 1)).gap, isNull, reason: 'a one-day run');
    final gap = Streak.of(journal([2, 3]), const StreakState(patches: 1)).gap!;
    expect(Streak.of(journal([2, 3]), StreakState(patches: 1, declined: {gap.from})).gap, isNull);
  });

  test('patched days count toward the streak', () {
    final j = journal([0, 2, 3]);
    final gap = Streak.of(journal([2, 3]), const StreakState(patches: 1)).gap!;
    final s = Streak.of(j, StreakState(patches: 0, patched: {gap.from}));
    expect(s.current, 4);
    expect(s.dayOf(j.todayDate.subtract(const Duration(days: 1))), StreakDay.patched);
  });

  test('a missed day ends the streak when it is not patched', () {
    expect(Streak.of(journal([0, 2, 3, 4]), const StreakState()).current, 1);
  });

  test('longest keeps the best run', () {
    expect(Streak.of(journal([0, 1]), const StreakState(longest: 9)).longest, 9);
    expect(Streak.of(journal([0, 1, 2]), const StreakState(longest: 2)).longest, 3);
  });
}
