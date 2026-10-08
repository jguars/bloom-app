import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/clock.dart';
import 'journal.dart';
import 'today.dart';

/// Which list a rule belongs to: the Do's, or the Don'ts.
enum PlanKind { more, skip }

/// Paws for the first log of a rule each day; each repeat up to its daily goal earns
/// [kPawsPerRepeat], and logs past the goal are still recorded, without paws.
const kPawsPerRule = 2;
const kPawsPerRepeat = 1;

/// Paws for the [n]th log (from 1) of a rule with a daily [goal].
int pawsFor(int n, int goal) => n == 1 ? kPawsPerRule : (n <= goal ? kPawsPerRepeat : 0);

/// Icons for rules. The design system rules out emoji, so rules get a small
/// line icon on a tile instead.
const planIcons = <String, IconData>{
  'water': Icons.water_drop_outlined,
  'walk': Icons.directions_walk_rounded,
  'veg': Icons.eco_outlined,
  'sleep': Icons.bedtime_outlined,
  'stretch': Icons.self_improvement_rounded,
  'stairs': Icons.stairs_outlined,
  'fruit': Icons.spa_outlined,
  'sun': Icons.wb_sunny_outlined,
  'drink': Icons.local_drink_outlined,
  'night': Icons.nightlight_outlined,
  'fastfood': Icons.fastfood_outlined,
  'cake': Icons.cake_outlined,
  'screen': Icons.phone_iphone_rounded,
  'bar': Icons.sports_bar_outlined,
  'snack': Icons.cookie_outlined,
  'plate': Icons.restaurant_outlined,
};

IconData iconFor(String key) => planIcons[key] ?? Icons.star_outline_rounded;

/// A rule is once a day ([goal] 1) or repeatable: logged up to [goal] times a day, and after each
/// log it rests for [rest] minutes at the bottom of the list before floating back up.
class PlanRule {
  const PlanRule({required this.id, required this.kind, required this.title, required this.icon, this.goal = 1, this.rest = 90});
  final String id;
  final PlanKind kind;
  final String title;
  final String icon;
  final int goal;
  final int rest;

  bool get repeats => goal > 1;

  PlanRule copyWith({PlanKind? kind, String? title, String? icon, int? goal, int? rest}) =>
      PlanRule(id: id, kind: kind ?? this.kind, title: title ?? this.title, icon: icon ?? this.icon, goal: goal ?? this.goal, rest: rest ?? this.rest);

  Map<String, Object?> toJson() => {'id': id, 'kind': kind.name, 'title': title, 'icon': icon, 'goal': goal, 'rest': rest};
  factory PlanRule.fromJson(Map<String, Object?> j) => PlanRule(
        id: j['id'] as String,
        kind: PlanKind.values.byName(j['kind'] as String),
        title: j['title'] as String,
        icon: j['icon'] as String? ?? 'sun',
        goal: (j['goal'] as num?)?.toInt() ?? 1,
        rest: (j['rest'] as num?)?.toInt() ?? 90,
      );
}

class Suggestion {
  const Suggestion(this.icon, this.title, [this.goal = 1, this.rest = 90]);
  final String icon, title;
  final int goal, rest;
}

const moreSuggestions = [
  Suggestion('water', 'Drink water', 8, 90),
  Suggestion('stairs', 'Take the stairs', 4, 60),
  Suggestion('stretch', 'Stretch break', 3, 120),
  Suggestion('walk', 'Morning walk'),
  Suggestion('veg', 'Vegetables with lunch'),
  Suggestion('sleep', 'In bed by 11'),
];

const skipSuggestions = [
  Suggestion('snack', 'Snacks between meals', 5, 30),
  Suggestion('drink', 'Sugary drinks', 3, 60),
  Suggestion('fastfood', 'Fast food'),
  Suggestion('night', 'Late-night snacks'),
  Suggestion('screen', 'Eating in front of a screen'),
  Suggestion('bar', 'Alcohol on weeknights'),
];

/// The rules and today's logs (when each rule was logged, in epoch ms, oldest first).
class Plan {
  const Plan({required this.rules, required this.day, required this.logs, this.loaded = false});
  final List<PlanRule> rules;
  final String day;
  final Map<String, List<int>> logs;
  final bool loaded;

  List<PlanRule> of(PlanKind k) => rules.where((r) => r.kind == k).toList();
  int count(String id) => logs[id]?.length ?? 0;
  bool isKept(String id) => count(id) > 0;
  int get keptCount => rules.where((r) => isKept(r.id)).length;
  int get logCount => rules.fold(0, (a, r) => a + count(r.id));
  int get pawsToday => rules.fold(0, (a, r) => a + [for (var n = 1; n <= count(r.id); n++) pawsFor(n, r.goal)].fold(0, (x, y) => x + y));

  /// When a logged repeatable rule floats back up, or null once it's done for the day.
  DateTime? backAt(PlanRule r) {
    final n = count(r.id);
    if (n == 0 || n >= r.goal) return null;
    return DateTime.fromMillisecondsSinceEpoch(logs[r.id]!.last).add(Duration(minutes: r.rest));
  }

  /// Up next: not logged yet, or rested long enough to log again.
  bool isDue(PlanRule r, DateTime now) {
    if (count(r.id) == 0) return true;
    final at = backAt(r);
    return at != null && !now.isBefore(at);
  }

  /// The top of a list: the most frequent first (the biggest daily goal), then in the order added.
  List<PlanRule> upNext(PlanKind k, DateTime now) {
    final up = of(k).where((r) => isDue(r, now)).toList();
    return [for (final (_, r) in (up.indexed.toList()..sort((a, b) => b.$2.goal != a.$2.goal ? b.$2.goal - a.$2.goal : a.$1 - b.$1))) r];
  }

  /// The bottom of a list: logged and resting, the latest log last.
  List<PlanRule> logged(PlanKind k, DateTime now) =>
      of(k).where((r) => !isDue(r, now)).toList()..sort((a, b) => logs[a.id]!.last.compareTo(logs[b.id]!.last));

  /// The next time a resting rule floats back up.
  DateTime? nextBack(DateTime now) {
    DateTime? next;
    for (final r in rules) {
      final at = backAt(r);
      if (at != null && at.isAfter(now) && (next == null || at.isBefore(next))) next = at;
    }
    return next;
  }

  Plan copyWith({List<PlanRule>? rules, String? day, Map<String, List<int>>? logs, bool? loaded}) =>
      Plan(rules: rules ?? this.rules, day: day ?? this.day, logs: logs ?? this.logs, loaded: loaded ?? this.loaded);

  Map<String, Object?> toJson() => {'rules': [for (final r in rules) r.toJson()], 'day': day, 'logs': logs};
}

/// A starting plan so the room is never empty; every rule can be changed.
const _starter = [
  PlanRule(id: 'm1', kind: PlanKind.more, title: 'Drink water', icon: 'water', goal: 8, rest: 90),
  PlanRule(id: 'm2', kind: PlanKind.more, title: 'Morning walk', icon: 'walk'),
  PlanRule(id: 'm3', kind: PlanKind.more, title: '10-minute stretch', icon: 'stretch'),
  PlanRule(id: 's1', kind: PlanKind.skip, title: 'Sugary drinks', icon: 'drink', goal: 3, rest: 60),
  PlanRule(id: 's2', kind: PlanKind.skip, title: 'Fast food', icon: 'fastfood'),
  PlanRule(id: 's3', kind: PlanKind.skip, title: 'Late-night snacks', icon: 'night'),
];

class PlanNotifier extends Notifier<Plan> {
  static const _key = 'bloom.plan.v2', _oldKey = 'bloom.plan.v1';

  DateTime get _now => ref.read(clockProvider)();

  @override
  Plan build() {
    final today = dayKey(_now);
    _load(today);
    return Plan(rules: _starter, day: today, logs: const {});
  }

  Future<void> _load(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final old = raw == null ? prefs.getString(_oldKey) : null;
    if (raw == null && old == null) {
      state = state.copyWith(loaded: true);
      return;
    }
    final j = jsonDecode(raw ?? old!) as Map<String, Object?>;
    final rules = [for (final r in (j['rules'] as List? ?? const [])) PlanRule.fromJson((r as Map).cast<String, Object?>())];
    final sameDay = j['day'] == today;
    final logs = <String, List<int>>{};
    if (sameDay && raw != null) {
      for (final MapEntry(:key, :value) in ((j['logs'] as Map?) ?? const {}).entries) {
        logs[key as String] = (value as List).cast<num>().map((e) => e.toInt()).toList();
      }
    } else if (sameDay) {
      // v1 kept a tick per rule; each becomes one log.
      final at = _now.millisecondsSinceEpoch;
      for (final id in (j['kept'] as List?)?.cast<String>() ?? const <String>[]) {
        logs[id] = [at];
      }
    }
    state = Plan(rules: rules, day: today, logs: logs, loaded: true);
  }

  Future<void> _save() async {
    ref.read(journalProvider.notifier).logPlan(
      state.rules.where((r) => state.isKept(r.id)).map((r) => r.id).toList(),
      state.rules.length,
      {for (final r in state.rules) if (state.isKept(r.id)) r.id: state.count(r.id)},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// A new day starts with nothing logged.
  void _rollover() {
    final today = dayKey(_now);
    if (state.day != today) state = state.copyWith(day: today, logs: const {});
  }

  PlanRule? _rule(String id) => state.rules.where((r) => r.id == id).firstOrNull;

  /// Logs a rule once more; returns the paws it earned (0 once past its goal).
  int log(String id) {
    _rollover();
    final r = _rule(id);
    if (r == null) return 0;
    final n = state.count(id) + 1;
    final paws = pawsFor(n, r.goal);
    state = state.copyWith(logs: {...state.logs, id: [...?state.logs[id], _now.millisecondsSinceEpoch]});
    if (paws > 0) ref.read(todayProvider.notifier).addPaws(paws);
    _save();
    return paws;
  }

  /// Takes back the latest log of a rule, and its paws.
  void unlog(String id) {
    final r = _rule(id);
    final n = state.count(id);
    if (r == null || n == 0) return;
    final paws = pawsFor(n, r.goal);
    final list = [...state.logs[id]!]..removeLast();
    state = state.copyWith(logs: {...state.logs, id: list}..removeWhere((_, v) => v.isEmpty));
    if (paws > 0) ref.read(todayProvider.notifier).addPaws(-paws);
    _save();
  }

  int _pawsOf(String id) {
    final r = _rule(id);
    if (r == null) return 0;
    return [for (var n = 1; n <= state.count(id); n++) pawsFor(n, r.goal)].fold(0, (a, b) => a + b);
  }

  /// Ticks a rule (one log) or, if it has any logs today, clears them all; moves paws with it.
  bool toggle(String id) {
    if (!state.isKept(id)) {
      log(id);
      return true;
    }
    final paws = _pawsOf(id);
    state = state.copyWith(logs: {...state.logs}..remove(id));
    if (paws > 0) ref.read(todayProvider.notifier).addPaws(-paws);
    _save();
    return false;
  }

  void add(PlanKind kind, String title, String icon, {int goal = 1, int rest = 90}) {
    final id = '${kind.name}-${DateTime.now().microsecondsSinceEpoch}';
    state = state.copyWith(rules: [...state.rules, PlanRule(id: id, kind: kind, title: title.trim(), icon: icon, goal: goal, rest: rest)]);
    _save();
  }

  void update(PlanRule rule) {
    state = state.copyWith(rules: [for (final r in state.rules) r.id == rule.id ? rule : r]);
    _save();
  }

  /// Removes a rule (and today's logs and paws for it); returns where it was so it can be put back.
  (int, List<int>) remove(String id) {
    final i = state.rules.indexWhere((r) => r.id == id);
    final paws = _pawsOf(id);
    final logs = state.logs[id] ?? const <int>[];
    state = state.copyWith(rules: state.rules.where((r) => r.id != id).toList(), logs: {...state.logs}..remove(id));
    if (paws > 0) ref.read(todayProvider.notifier).addPaws(-paws);
    _save();
    return (i, logs);
  }

  void restore(PlanRule rule, (int, List<int>) at) {
    final (index, logs) = at;
    final list = [...state.rules]..insert(index.clamp(0, state.rules.length), rule);
    state = state.copyWith(rules: list, logs: logs.isEmpty ? state.logs : {...state.logs, rule.id: logs});
    final paws = _pawsOf(rule.id);
    if (paws > 0) ref.read(todayProvider.notifier).addPaws(paws);
    _save();
  }
}

final planProvider = NotifierProvider<PlanNotifier, Plan>(PlanNotifier.new);
