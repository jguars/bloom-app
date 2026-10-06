import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Planned pace: a steady, sustainable 0.7 kg a week.
const double kPlannedKgPerWeek = 0.7;

class WeightEntry {
  const WeightEntry(this.at, this.kg);
  final DateTime at;
  final double kg;

  Map<String, Object?> toJson() => {'at': at.toIso8601String(), 'kg': kg};
  factory WeightEntry.fromJson(Map<String, Object?> j) => WeightEntry(DateTime.parse(j['at'] as String), (j['kg'] as num).toDouble());
}

/// Every weigh-in (any number a day) and the goal. Only the user sees this;
/// Clover's shape never follows it.
class WeightLog {
  const WeightLog({required this.entries, this.goalKg, this.kgPerWeek = kPlannedKgPerWeek, this.loaded = false});

  /// Oldest first.
  final List<WeightEntry> entries;
  final double? goalKg;
  final double kgPerWeek;
  final bool loaded;

  WeightEntry? get first => entries.firstOrNull;
  WeightEntry? get latest => entries.lastOrNull;

  /// Change since the first weigh-in (negative = lighter).
  double get change => entries.length < 2 ? 0 : latest!.kg - first!.kg;

  /// The last weigh-in on or before [t].
  WeightEntry? at(DateTime t) {
    for (final e in entries.reversed) {
      if (!e.at.isAfter(t)) return e;
    }
    return null;
  }

  /// Change over the last 7 days, or null without a weigh-in a week back.
  double? get weekChange {
    final l = latest;
    if (l == null) return null;
    final before = at(l.at.subtract(const Duration(days: 7)));
    return before == null ? (entries.length > 1 ? l.kg - first!.kg : null) : l.kg - before.kg;
  }

  /// Where the plan expects the user on [day]: a straight line down from the
  /// first weigh-in, stopping at the goal.
  double? plannedOn(DateTime day) {
    final start = first;
    if (start == null) return null;
    final days = day.difference(start.at).inHours / 24;
    final kg = start.kg - kgPerWeek * days / 7;
    final goal = goalKg;
    return goal == null || goal >= start.kg ? kg : (kg < goal ? goal : kg);
  }

  /// When the plan reaches the goal, if one is set below the start.
  DateTime? get goalDate {
    final start = first;
    final goal = goalKg;
    if (start == null || goal == null || goal >= start.kg) return null;
    final days = (start.kg - goal) / kgPerWeek * 7;
    return start.at.add(Duration(hours: (days * 24).round()));
  }

  WeightLog copyWith({List<WeightEntry>? entries, double? goalKg, double? kgPerWeek, bool? loaded}) => WeightLog(
        entries: entries ?? this.entries,
        goalKg: goalKg ?? this.goalKg,
        kgPerWeek: kgPerWeek ?? this.kgPerWeek,
        loaded: loaded ?? this.loaded,
      );

  Map<String, Object?> toJson() => {'entries': [for (final e in entries) e.toJson()], 'goalKg': goalKg, 'kgPerWeek': kgPerWeek};

  factory WeightLog.fromJson(Map<String, Object?> j) => WeightLog(
        entries: [for (final e in (j['entries'] as List? ?? const [])) WeightEntry.fromJson((e as Map).cast<String, Object?>())],
        goalKg: (j['goalKg'] as num?)?.toDouble(),
        kgPerWeek: (j['kgPerWeek'] as num?)?.toDouble() ?? kPlannedKgPerWeek,
        loaded: true,
      );
}

class WeightNotifier extends Notifier<WeightLog> {
  static const _key = 'bloom.weight.v1';

  @override
  WeightLog build() {
    _load();
    return const WeightLog(entries: []);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = raw == null ? state.copyWith(loaded: true) : WeightLog.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  void log(double kg, [DateTime? at]) {
    final entries = [...state.entries, WeightEntry(at ?? DateTime.now(), double.parse(kg.toStringAsFixed(2)))]..sort((a, b) => a.at.compareTo(b.at));
    state = state.copyWith(entries: entries);
    _save();
  }

  /// Removes [entry]; returns where it was so it can be put back with [log].
  void remove(WeightEntry entry) {
    state = state.copyWith(entries: state.entries.where((e) => !identical(e, entry)).toList());
    _save();
  }

  void setGoal(double kg) {
    state = state.copyWith(goalKg: double.parse(kg.toStringAsFixed(2)));
    _save();
  }
}

final weightProvider = NotifierProvider<WeightNotifier, WeightLog>(WeightNotifier.new);
