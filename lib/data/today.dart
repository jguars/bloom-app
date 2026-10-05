import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercises.dart';

/// Bonus for doing all three moves in a day.
const kDailyBonus = 15;

/// Moves per day that fill the ring.
const kDailyGoal = 3;

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Everything the Today room needs.
class TodayState {
  const TodayState({
    required this.day,
    required this.done,
    required this.pick,
    required this.paws,
    required this.bonusPaid,
    this.loaded = false,
  });

  final String day;

  /// Moves finished today.
  final int done;

  /// Index into today's picks.
  final int pick;

  /// Paws balance.
  final int paws;
  final bool bonusPaid;
  final bool loaded;

  List<Exercise> get picks => picksFor(day);
  Exercise get current => picks[pick % picks.length];
  bool get goalMet => done >= kDailyGoal;

  TodayState copyWith({String? day, int? done, int? pick, int? paws, bool? bonusPaid, bool? loaded}) => TodayState(
        day: day ?? this.day,
        done: done ?? this.done,
        pick: pick ?? this.pick,
        paws: paws ?? this.paws,
        bonusPaid: bonusPaid ?? this.bonusPaid,
        loaded: loaded ?? this.loaded,
      );

  Map<String, Object?> toJson() => {'day': day, 'done': done, 'pick': pick, 'paws': paws, 'bonus': bonusPaid};
}

/// What finishing a move earned, so the UI can celebrate each part.
class Reward {
  const Reward({required this.paws, required this.bonus, required this.doneNow});
  final int paws;
  final int bonus;
  final int doneNow;
}

class TodayNotifier extends Notifier<TodayState> {
  static const _key = 'bloom.today.v1';

  @override
  TodayState build() {
    final today = dayKey(DateTime.now());
    _load(today);
    return TodayState(day: today, done: 0, pick: 0, paws: 0, bonusPaid: false);
  }

  Future<void> _load(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      // First launch: a small welcome balance so the Shop isn't empty-handed.
      state = state.copyWith(paws: 120, loaded: true);
      _save();
      return;
    }
    final j = jsonDecode(raw) as Map<String, Object?>;
    final paws = (j['paws'] as num?)?.toInt() ?? 0;
    if (j['day'] == today) {
      state = TodayState(
        day: today,
        done: (j['done'] as num?)?.toInt() ?? 0,
        pick: (j['pick'] as num?)?.toInt() ?? 0,
        paws: paws,
        bonusPaid: j['bonus'] == true,
        loaded: true,
      );
    } else {
      // A new day: the ring empties, the balance stays.
      state = TodayState(day: today, done: 0, pick: 0, paws: paws, bonusPaid: false, loaded: true);
      _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// "Show me something else".
  void swap() {
    state = state.copyWith(pick: (state.pick + 1) % state.picks.length);
    _save();
  }

  /// Marks the current move done. Paws are added by [collect], after the
  /// celebration, so the balance moves while the user is watching it.
  Reward finish() {
    final ex = state.current;
    final doneNow = (state.done + 1).clamp(0, 99);
    final bonus = (doneNow >= kDailyGoal && !state.bonusPaid) ? kDailyBonus : 0;
    state = state.copyWith(done: doneNow, pick: (state.pick + 1) % state.picks.length, bonusPaid: state.bonusPaid || bonus > 0);
    _save();
    return Reward(paws: ex.paws, bonus: bonus, doneNow: doneNow);
  }

  void addPaws(int n) {
    state = state.copyWith(paws: (state.paws + n).clamp(0, 1 << 30));
    _save();
  }
}

final todayProvider = NotifierProvider<TodayNotifier, TodayState>(TodayNotifier.new);
