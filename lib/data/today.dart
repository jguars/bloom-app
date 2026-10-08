import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'equipment.dart';
import 'exercises.dart';
import 'journal.dart';

/// Bonus for doing all three moves in a day.
const kDailyBonus = 15;

/// Moves per day that fill the ring.
const kDailyGoal = 3;

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Bonus moves allowed once the day's three are done; they earn half paws.
const kExtraCap = 2;

/// Days a move stays out of the daily set after it appeared.
const _restDays = 2;

/// Everything the Today room needs: the day's set of three moves (one to get moving, one for
/// strength, one to stretch), which are done, the extras taken after them, and the balance.
class TodayState {
  const TodayState({
    required this.day,
    required this.paws,
    required this.bonusPaid,
    this.set = const [],
    this.doneIds = const {},
    this.swappedSlots = const {},
    this.extras = 0,
    this.recent = const [],
    this.swapCounts = const {},
    this.benched = const {},
    this.seen = const {},
    this.owned = const [],
    this.limits = const {},
    this.gentle = false,
    this.loaded = false,
  });

  final String day;

  /// Today's three move ids, in slot order.
  final List<String> set;

  /// Which of [set] are done.
  final Set<String> doneIds;

  /// Slots already swapped today (one swap per slot).
  final Set<int> swappedSlots;

  /// Bonus moves done after the three (at most [kExtraCap]).
  final int extras;

  /// Ids from the last [_restDays] days' sets, kept out of new sets.
  final List<String> recent;

  /// How often each move was swapped away; two swaps bench it for a week.
  final Map<String, int> swapCounts;

  /// Moves sitting out, with the day they come back.
  final Map<String, String> benched;

  /// Moves that have been in a set at least once (new gear moves are offered first).
  final Set<String> seen;

  /// Paws balance.
  final int paws;
  final bool bonusPaid;

  /// Gear ids owned, in the order bought.
  final List<String> owned;

  /// From onboarding: areas to go easy on, and whether to favour lighter moves.
  final Set<String> limits;
  final bool gentle;
  final bool loaded;

  List<Exercise> get moves => [for (final id in set) ?exerciseById(id)];
  int get done => doneIds.length;
  bool get goalMet => set.isNotEmpty && done >= set.length;

  /// The first move of the set not done yet.
  Exercise? get next => moves.where((e) => !doneIds.contains(e.id)).firstOrNull;
  bool get extrasLeft => extras < kExtraCap;
  bool owns(String id) => owned.contains(id);

  TodayState copyWith({
    String? day,
    List<String>? set,
    Set<String>? doneIds,
    Set<int>? swappedSlots,
    int? extras,
    List<String>? recent,
    Map<String, int>? swapCounts,
    Map<String, String>? benched,
    Set<String>? seen,
    int? paws,
    bool? bonusPaid,
    List<String>? owned,
    Set<String>? limits,
    bool? gentle,
    bool? loaded,
  }) =>
      TodayState(
        day: day ?? this.day,
        set: set ?? this.set,
        doneIds: doneIds ?? this.doneIds,
        swappedSlots: swappedSlots ?? this.swappedSlots,
        extras: extras ?? this.extras,
        recent: recent ?? this.recent,
        swapCounts: swapCounts ?? this.swapCounts,
        benched: benched ?? this.benched,
        seen: seen ?? this.seen,
        paws: paws ?? this.paws,
        bonusPaid: bonusPaid ?? this.bonusPaid,
        owned: owned ?? this.owned,
        limits: limits ?? this.limits,
        gentle: gentle ?? this.gentle,
        loaded: loaded ?? this.loaded,
      );

  Map<String, Object?> toJson() => {
        'day': day,
        'set': set,
        'doneIds': doneIds.toList(),
        'swapped': swappedSlots.toList(),
        'extras': extras,
        'recent': recent,
        'swapCounts': swapCounts,
        'benched': benched,
        'seen': seen.toList(),
        'paws': paws,
        'bonus': bonusPaid,
        'owned': owned,
        'limits': limits.toList(),
        'gentle': gentle,
      };
}

/// How a finished move counted.
enum MoveCredit { daily, extra, fun }

/// What finishing a move earned, so the UI can celebrate each part.
class Reward {
  const Reward({required this.paws, required this.bonus, required this.doneNow, this.flag, this.credit = MoveCredit.daily});
  final int paws;
  final int bonus;

  /// The day's set done so far, after this move.
  final int doneNow;

  /// A journey flag this move just reached, if any.
  final Milestone? flag;
  final MoveCredit credit;
}

int _seedOf(String s) => s.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);

String _addDays(String day, int n) {
  final d = DateTime.parse(day).add(Duration(days: n));
  return dayKey(d);
}

/// Picks a day's three: one of each [MoveKind], none from [recent] or [benched] when avoidable, and a
/// gear move never offered before ([seen]) first in its slot, so new gear shows up right away.
List<String> chooseSet(String day, List<Exercise> pool, {List<String> recent = const [], Map<String, String> benched = const {}, Set<String> seen = const {}}) {
  final seed = _seedOf(day);
  final out = <String>[];
  for (final kind in MoveKind.values) {
    final ofKind = pool.where((e) => kindOf(e) == kind && !out.contains(e.id)).toList();
    if (ofKind.isEmpty) continue;
    bool sittingOut(Exercise e) => (benched[e.id] ?? '').compareTo(day) > 0;
    var fresh = ofKind.where((e) => !recent.contains(e.id) && !sittingOut(e)).toList();
    if (fresh.isEmpty) fresh = ofKind.where((e) => !sittingOut(e)).toList();
    if (fresh.isEmpty) fresh = ofKind;
    final newGear = fresh.where((e) => e.equipment != null && !seen.contains(e.id)).toList();
    final from = newGear.isNotEmpty ? newGear : fresh;
    out.add(from[(seed + kind.index * 7) % from.length].id);
  }
  // Too few kinds (e.g. strict limits): fill up with anything not in the set.
  for (final e in pool) {
    if (out.length >= kDailyGoal) break;
    if (!out.contains(e.id)) out.add(e.id);
  }
  return out;
}

class TodayNotifier extends Notifier<TodayState> {
  static const _key = 'bloom.today.v2';
  static const _oldKey = 'bloom.today.v1';

  @override
  TodayState build() {
    final today = dayKey(DateTime.now());
    _load(today);
    return TodayState(day: today, paws: 0, bonusPaid: false);
  }

  List<Exercise> _pool(TodayState s) => eligibleMoves(owned: s.owned.toSet(), limits: s.limits, gentle: s.gentle);

  /// A fresh set for [s.day], remembering what it offered.
  TodayState _newSet(TodayState s) {
    final set = chooseSet(s.day, _pool(s), recent: s.recent, benched: s.benched, seen: s.seen);
    return s.copyWith(set: set, doneIds: {}, swappedSlots: {}, extras: 0, bonusPaid: false, seen: {...s.seen, ...set});
  }

  Future<void> _load(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? prefs.getString(_oldKey);
    if (raw == null) {
      // First launch: a small welcome balance so the Shop isn't empty-handed.
      state = _newSet(state.copyWith(paws: 120, loaded: true));
      _save();
      return;
    }
    final j = jsonDecode(raw) as Map<String, Object?>;
    List<String> strs(Object? v) => ((v as List?) ?? const []).cast<String>();
    var s = TodayState(
      day: today,
      paws: (j['paws'] as num?)?.toInt() ?? 0,
      bonusPaid: false,
      owned: strs(j['owned']),
      limits: strs(j['limits']).toSet(),
      gentle: j['gentle'] == true,
      recent: strs(j['recent']),
      swapCounts: ((j['swapCounts'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
      benched: ((j['benched'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String)),
      seen: strs(j['seen']).toSet(),
      loaded: true,
    );
    final set = strs(j['set']);
    if (j['day'] == today && set.isNotEmpty) {
      s = s.copyWith(
        set: set,
        doneIds: strs(j['doneIds']).toSet(),
        swappedSlots: ((j['swapped'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet(),
        extras: (j['extras'] as num?)?.toInt() ?? 0,
        bonusPaid: j['bonus'] == true,
      );
      state = s;
    } else {
      // A new day: yesterday's set rests for a couple of days, and a new three arrive.
      final recent = [...set, ...s.recent].take(_restDays * kDailyGoal).toList();
      state = _newSet(s.copyWith(recent: recent));
      _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// Swaps the move in [slot] for another of the same kind (once per slot a day). A move swapped
  /// away twice sits out for a week.
  void swap(int slot) {
    final s = state;
    if (slot >= s.set.length || s.swappedSlots.contains(slot) || s.doneIds.contains(s.set[slot])) return;
    final old = s.set[slot];
    final kind = kindOf(exerciseById(old)!);
    final options = _pool(s).where((e) => kindOf(e) == kind && !s.set.contains(e.id) && (s.benched[e.id] ?? '').compareTo(s.day) <= 0).toList();
    final fresh = options.where((e) => !s.recent.contains(e.id)).toList();
    final from = fresh.isNotEmpty ? fresh : options;
    if (from.isEmpty) return;
    final pick = from[(_seedOf(s.day) + slot) % from.length].id;
    final count = (s.swapCounts[old] ?? 0) + 1;
    state = s.copyWith(
      set: [...s.set]..[slot] = pick,
      swappedSlots: {...s.swappedSlots, slot},
      swapCounts: {...s.swapCounts, old: count >= 2 ? 0 : count},
      benched: count >= 2 ? {...s.benched, old: _addDays(s.day, 7)} : s.benched,
      seen: {...s.seen, pick},
    );
    _save();
  }

  /// Marks [ex] done. A move from the set counts fully (and the third adds the day's bonus); after
  /// the three, up to [kExtraCap] extras earn half paws; beyond that a move is just for fun.
  /// Paws are added by [addPaws] after the celebration, so the balance moves while the user watches.
  /// Only the day's three move Clover along her journey.
  Reward finish(Exercise ex) {
    final s = state;
    if (s.set.contains(ex.id) && !s.doneIds.contains(ex.id)) {
      final doneIds = {...s.doneIds, ex.id};
      final bonus = doneIds.length >= s.set.length && !s.bonusPaid ? kDailyBonus : 0;
      state = s.copyWith(doneIds: doneIds, bonusPaid: s.bonusPaid || bonus > 0);
      _save();
      final before = ref.read(journalProvider).next;
      ref.read(journalProvider.notifier).logMove(ex);
      final after = ref.read(journalProvider).next;
      return Reward(paws: ex.paws, bonus: bonus, doneNow: doneIds.length, flag: before != null && before != after ? before : null);
    }
    if (s.goalMet && s.extrasLeft) {
      state = s.copyWith(extras: s.extras + 1);
      _save();
      return Reward(paws: (ex.paws / 2).ceil(), bonus: 0, doneNow: s.done, credit: MoveCredit.extra);
    }
    return Reward(paws: 0, bonus: 0, doneNow: s.done, credit: MoveCredit.fun);
  }

  /// Puts [ex] into today's set as the next move (e.g. "Try it with Clover" right after unlocking
  /// gear), in place of the first not-done move of its kind.
  void pickExercise(Exercise ex) {
    final s = state;
    if (s.goalMet || s.set.contains(ex.id)) return;
    var slot = s.set.indexWhere((id) => !s.doneIds.contains(id) && kindOf(exerciseById(id)!) == kindOf(ex));
    if (slot < 0) slot = s.set.indexWhere((id) => !s.doneIds.contains(id));
    if (slot < 0) return;
    final set = [...s.set]..[slot] = ex.id;
    // Move it to the front of the not-done ones so it's "next".
    final firstOpen = set.indexWhere((id) => !s.doneIds.contains(id));
    if (firstOpen >= 0 && firstOpen != slot) {
      set[slot] = set[firstOpen];
      set[firstOpen] = ex.id;
    }
    state = s.copyWith(set: set, seen: {...s.seen, ex.id});
    _save();
  }

  /// Onboarding answers that shape her picks.
  void setPreferences({required Set<String> limits, required bool gentle}) {
    final s = state.copyWith(limits: limits, gentle: gentle);
    state = s.done == 0 ? _newSet(s) : s;
    _save();
  }

  /// Buys [item] if affordable. Returns false (and changes nothing) if not.
  bool buy(Equipment item) {
    if (state.owns(item.id) || state.paws < item.price) return false;
    state = state.copyWith(paws: state.paws - item.price, owned: [...state.owned, item.id]);
    _save();
    return true;
  }

  void addPaws(int n) {
    state = state.copyWith(paws: (state.paws + n).clamp(0, 1 << 30));
    _save();
  }
}

final todayProvider = NotifierProvider<TodayNotifier, TodayState>(TodayNotifier.new);
