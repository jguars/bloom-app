import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercises.dart';
import 'today.dart';

/// Total effort at which Clover reaches her fit shape (bodyMass 0).
const double kTargetEffort = 120;

/// The planned pace: about two moves a day reaches the target on day 60.
const double kPlannedEffortPerDay = kTargetEffort / 60;

/// A flag on her journey. Flags are reached by effort, not by the calendar:
/// working ahead reaches them early, and a slow week never takes one away.
class Milestone {
  const Milestone(this.day, this.title, this.line);
  final int day;
  final String title, line;

  double get effort => day * kPlannedEffortPerDay;

  /// The shape the plan expects by then (100 = softest, 0 = fit).
  double get bodyMass => (100 * (1 - day / 60)).clamp(0, 100).toDouble();
  String get tag => 'D$day';
}

const milestones = [
  Milestone(0, 'Day one', 'Where we started, on the sofa.'),
  Milestone(7, 'First week', 'Getting the hang of it.'),
  Milestone(15, 'Two weeks in', 'Lighter on our feet.'),
  Milestone(30, 'One month', 'Look at us go!'),
  Milestone(60, 'Two months', 'Fit and happy, together.'),
];

/// One day's record: moves done together and plan rules kept.
/// The evening check-in answer.
enum CheckIn {
  all('Stuck to it', 'Proud of us! Sleep well.'),
  mostly('Mostly', 'Mostly is plenty. Tomorrow’s a fresh page.'),
  not('Not today', 'That’s okay. I saved you a spot on the mat.');

  const CheckIn(this.label, this.reply);
  final String label;

  /// What Clover says back. Never shaming.
  final String reply;
}

/// Paws for checking in, whatever the answer.
const kCheckInPaws = 5;

class DayLog {
  const DayLog({this.moves = 0, this.seconds = 0, this.kept = const [], this.rules = 0, this.checkIn});
  final int moves, seconds;
  final CheckIn? checkIn;

  /// Ids of plan rules kept that day.
  final List<String> kept;

  /// How many rules the plan had that day.
  final int rules;

  DayLog copyWith({int? moves, int? seconds, List<String>? kept, int? rules, CheckIn? checkIn}) =>
      DayLog(moves: moves ?? this.moves, seconds: seconds ?? this.seconds, kept: kept ?? this.kept, rules: rules ?? this.rules, checkIn: checkIn ?? this.checkIn);

  Map<String, Object?> toJson() => {'m': moves, 's': seconds, 'k': kept, 'r': rules, if (checkIn != null) 'c': checkIn!.name};
  factory DayLog.fromJson(Map<String, Object?> j) => DayLog(
        moves: (j['m'] as num?)?.toInt() ?? 0,
        seconds: (j['s'] as num?)?.toInt() ?? 0,
        kept: (j['k'] as List?)?.cast<String>() ?? const [],
        rules: (j['r'] as num?)?.toInt() ?? 0,
        checkIn: CheckIn.values.asNameMap()[j['c']],
      );
}

/// The shared history: when the journey began, the effort put in, and a log
/// per day. Clover's body follows [effort], which only ever goes up.
class Journal {
  const Journal({required this.start, required this.today, this.effort = 0, this.days = const {}, this.loaded = false});
  final String start, today;
  final double effort;
  final Map<String, DayLog> days;
  final bool loaded;

  DateTime get startDate => DateTime.parse(start);
  DateTime get todayDate => DateTime.parse(today);

  /// Whole days since the start (D0 = 0).
  int get dayNumber => todayDate.difference(startDate).inDays;

  /// 100 = softest (start), 0 = fit. Drives Clover's `bodyMass`.
  double get bodyMass => (100 * (1 - effort / kTargetEffort)).clamp(0, 100).toDouble();

  bool reached(Milestone m) => effort >= m.effort;
  Milestone? get next => milestones.where((m) => !reached(m)).firstOrNull;

  /// The calendar date the plan puts [m] on.
  DateTime dateOf(Milestone m) => startDate.add(Duration(days: m.day));

  /// 0..1 share of the way to the next flag from the last one.
  double toward(Milestone m) {
    final i = milestones.indexOf(m);
    final from = i == 0 ? 0.0 : milestones[i - 1].effort;
    return ((effort - from) / (m.effort - from)).clamp(0.0, 1.0);
  }

  /// 0..1 along the whole timeline, for the journey track.
  double get trackFill {
    for (var i = 1; i < milestones.length; i++) {
      final m = milestones[i];
      if (!reached(m)) return ((i - 1) + toward(m)) / (milestones.length - 1);
    }
    return 1;
  }

  DayLog on(DateTime d) => days[dayKey(d)] ?? const DayLog();
  DayLog get todayLog => days[today] ?? const DayLog();
  int get totalMoves => days.values.fold(0, (a, d) => a + d.moves);

  /// Monday to Sunday of the week containing today.
  List<DateTime> get week {
    final t = todayDate;
    final monday = t.subtract(Duration(days: t.weekday - 1));
    return [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
  }

  Journal copyWith({String? start, String? today, double? effort, Map<String, DayLog>? days, bool? loaded}) => Journal(
        start: start ?? this.start,
        today: today ?? this.today,
        effort: effort ?? this.effort,
        days: days ?? this.days,
        loaded: loaded ?? this.loaded,
      );

  Map<String, Object?> toJson() => {'start': start, 'effort': effort, 'days': {for (final e in days.entries) e.key: e.value.toJson()}};
}

class JournalNotifier extends Notifier<Journal> {
  static const _key = 'bloom.journal.v1';

  @override
  Journal build() {
    final today = dayKey(DateTime.now());
    _load(today);
    return Journal(start: today, today: today);
  }

  Future<void> _load(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      state = state.copyWith(loaded: true);
      _save();
      return;
    }
    final j = jsonDecode(raw) as Map<String, Object?>;
    final days = <String, DayLog>{
      for (final e in ((j['days'] as Map?) ?? const {}).entries) e.key as String: DayLog.fromJson((e.value as Map).cast<String, Object?>()),
    };
    state = Journal(start: j['start'] as String? ?? today, today: today, effort: (j['effort'] as num?)?.toDouble() ?? 0, days: days, loaded: true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  DayLog get _todayLog => state.days[state.today] ?? const DayLog();

  void _put(DayLog d) {
    final days = {...state.days, state.today: d};
    // Keep about four months; nothing older is shown.
    if (days.length > 120) {
      final keys = days.keys.toList()..sort();
      for (final k in keys.take(days.length - 120)) {
        days.remove(k);
      }
    }
    state = state.copyWith(days: days);
  }

  /// A move finished together.
  void logMove(Exercise ex) {
    final d = _todayLog;
    _put(d.copyWith(moves: d.moves + 1, seconds: d.seconds + ex.seconds));
    state = state.copyWith(effort: state.effort + ex.effort);
    _save();
  }

  /// The evening check-in. Returns true the first time today (paws are due).
  bool logCheckIn(CheckIn c) {
    final first = _todayLog.checkIn == null;
    _put(_todayLog.copyWith(checkIn: c));
    _save();
    return first;
  }

  /// Today's plan as it stands: which rules are kept, out of how many.
  void logPlan(List<String> kept, int rules) {
    _put(_todayLog.copyWith(kept: kept, rules: rules));
    _save();
  }
}

final journalProvider = NotifierProvider<JournalNotifier, Journal>(JournalNotifier.new);
