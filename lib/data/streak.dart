import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journal.dart';
import 'today.dart';

/// Paw Patches held at most at once.
const kMaxPatches = 2;

/// Streak days per patch earned.
const kDaysPerPatch = 7;

/// The streak's own memory: Paw Patches on hand, the days they covered, gaps the user chose to start fresh after
/// (so they aren't offered again), the longest streak, and the last day it was celebrated. A streak day is a day
/// with at least one move together (from the [Journal]); the rest is worked out from that.
class StreakState {
  const StreakState({this.patches = 1, this.patched = const {}, this.declined = const {}, this.longest = 0, this.celebrated, this.earned = const {}, this.loaded = false});

  /// Patches on hand (a new streaker starts with one, as a safety net).
  final int patches;

  /// Days covered by a patch (they count as streak days).
  final Set<String> patched;

  /// Gaps (by their first missed day) the user chose not to patch.
  final Set<String> declined;

  /// Days a patch was earned on (one per [kDaysPerPatch] streak days).
  final Set<String> earned;
  final int longest;

  /// The last day the streak celebration was shown.
  final String? celebrated;
  final bool loaded;

  StreakState copyWith({int? patches, Set<String>? patched, Set<String>? declined, Set<String>? earned, int? longest, String? celebrated, bool? loaded}) => StreakState(
        patches: patches ?? this.patches,
        patched: patched ?? this.patched,
        declined: declined ?? this.declined,
        earned: earned ?? this.earned,
        longest: longest ?? this.longest,
        celebrated: celebrated ?? this.celebrated,
        loaded: loaded ?? this.loaded,
      );

  Map<String, Object?> toJson() => {
        'p': patches,
        'pd': patched.toList(),
        'd': declined.toList(),
        'e': earned.toList(),
        'l': longest,
        if (celebrated != null) 'c': celebrated,
      };

  factory StreakState.fromJson(Map<String, Object?> j) => StreakState(
        patches: (j['p'] as num?)?.toInt() ?? 1,
        patched: {...?(j['pd'] as List?)?.cast<String>()},
        declined: {...?(j['d'] as List?)?.cast<String>()},
        earned: {...?(j['e'] as List?)?.cast<String>()},
        longest: (j['l'] as num?)?.toInt() ?? 0,
        celebrated: j['c'] as String?,
        loaded: true,
      );
}

/// How a day looks on the streak: moved, covered by a patch, missed, or not yet (today, before a move).
enum StreakDay { moved, patched, missed, open }

/// The streak as it stands today.
class Streak {
  const Streak({required this.current, required this.doneToday, required this.longest, required this.patches, required this.gap, required this.dayOf});

  /// Days in a row, counting today once it has a move (until then, the run up to yesterday stays alive).
  final int current;
  final bool doneToday;
  final int longest;
  final int patches;

  /// Days just missed (ending yesterday) that a patch could still cover: the run before them, and how many there
  /// are. Null when there's nothing to patch.
  final ({String from, int days, int run})? gap;

  final StreakDay Function(DateTime) dayOf;

  static Streak of(Journal j, StreakState s) {
    final today = j.todayDate;
    bool moved(DateTime d) => j.on(d).moves > 0;
    StreakDay dayOf(DateTime d) {
      if (d.isAfter(today)) return StreakDay.open;
      if (moved(d)) return StreakDay.moved;
      if (s.patched.contains(dayKey(d))) return StreakDay.patched;
      return dayKey(d) == j.today ? StreakDay.open : StreakDay.missed;
    }

    bool counts(DateTime d) => dayOf(d) == StreakDay.moved || dayOf(d) == StreakDay.patched;
    int runFrom(DateTime d) {
      var n = 0;
      while (counts(d) && !d.isBefore(j.startDate)) {
        n++;
        d = d.subtract(const Duration(days: 1));
      }
      return n;
    }

    final doneToday = counts(today);
    final yesterday = today.subtract(const Duration(days: 1));
    final current = doneToday ? runFrom(today) : runFrom(yesterday);
    // A gap: missed days ending yesterday, with a run before them worth saving, small enough for the patches.
    ({String from, int days, int run})? gap;
    if (!counts(yesterday) && yesterday.isAfter(j.startDate.subtract(const Duration(days: 1)))) {
      var d = yesterday, n = 0;
      while (!counts(d) && !d.isBefore(j.startDate) && n <= kMaxPatches) {
        n++;
        d = d.subtract(const Duration(days: 1));
      }
      final run = runFrom(d);
      final from = dayKey(d.add(const Duration(days: 1)));
      if (run >= 2 && n <= s.patches && !s.declined.contains(from)) gap = (from: from, days: n, run: run);
    }
    return Streak(current: current, doneToday: doneToday, longest: current > s.longest ? current : s.longest, patches: s.patches, gap: gap, dayOf: dayOf);
  }
}

class StreakNotifier extends Notifier<StreakState> {
  static const _key = 'bloom.streak.v1';

  @override
  StreakState build() {
    _load();
    return const StreakState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = raw == null ? state.copyWith(loaded: true) : StreakState.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// Whether today's streak celebration is due (a move today, not yet celebrated).
  bool celebrationDue(Journal j) => state.loaded && j.todayLog.moves > 0 && state.celebrated != j.today;

  /// Marks today celebrated; keeps the longest, and earns a patch every [kDaysPerPatch] days in a row. Returns
  /// whether a patch was earned.
  bool celebrate(Journal j) {
    final s = Streak.of(j, state);
    final earn = s.current > 0 && s.current % kDaysPerPatch == 0 && !state.earned.contains(j.today) && state.patches < kMaxPatches;
    state = state.copyWith(
      celebrated: j.today,
      longest: s.longest,
      patches: state.patches + (earn ? 1 : 0),
      earned: earn ? {...state.earned, j.today} : null,
    );
    _save();
    return earn;
  }

  /// Covers the missed days of [gap] with patches.
  void patch(Journal j, ({String from, int days, int run}) gap) {
    final from = DateTime.parse(gap.from);
    state = state.copyWith(
      patches: state.patches - gap.days,
      patched: {...state.patched, for (var i = 0; i < gap.days; i++) dayKey(from.add(Duration(days: i)))},
    );
    _save();
  }

  /// Leaves the gap as it is: the streak starts over, and this gap isn't offered again.
  void startFresh(({String from, int days, int run}) gap) {
    state = state.copyWith(declined: {...state.declined, gap.from});
    _save();
  }
}

final streakProvider = NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);

/// The streak, live from the journal and the streak's memory.
final streakNowProvider = Provider<Streak>((ref) => Streak.of(ref.watch(journalProvider), ref.watch(streakProvider)));
