import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'today.dart';

/// Which list a rule belongs to.
enum PlanKind { more, skip }

/// Each list stays short: a few rules kept beat a long list ignored.
const kMaxRules = 5;

/// Paws for each rule kept today.
const kPawsPerRule = 2;

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

class PlanRule {
  const PlanRule({required this.id, required this.kind, required this.title, required this.icon});
  final String id;
  final PlanKind kind;
  final String title;
  final String icon;

  PlanRule copyWith({PlanKind? kind, String? title, String? icon}) =>
      PlanRule(id: id, kind: kind ?? this.kind, title: title ?? this.title, icon: icon ?? this.icon);

  Map<String, Object?> toJson() => {'id': id, 'kind': kind.name, 'title': title, 'icon': icon};
  factory PlanRule.fromJson(Map<String, Object?> j) =>
      PlanRule(id: j['id'] as String, kind: PlanKind.values.byName(j['kind'] as String), title: j['title'] as String, icon: j['icon'] as String? ?? 'sun');
}

class Suggestion {
  const Suggestion(this.icon, this.title);
  final String icon, title;
}

const moreSuggestions = [
  Suggestion('walk', 'Morning walk'),
  Suggestion('water', 'Drink water first'),
  Suggestion('stretch', '10-minute stretch'),
  Suggestion('veg', 'Vegetables with lunch'),
  Suggestion('stairs', 'Take the stairs'),
  Suggestion('sleep', 'In bed by 11'),
];

const skipSuggestions = [
  Suggestion('drink', 'Sugary drinks'),
  Suggestion('fastfood', 'Fast food'),
  Suggestion('night', 'Late-night snacks'),
  Suggestion('screen', 'Eating in front of a screen'),
  Suggestion('cake', 'Desserts on weekdays'),
  Suggestion('bar', 'Alcohol on weeknights'),
];

class Plan {
  const Plan({required this.rules, required this.day, required this.kept, this.loaded = false});
  final List<PlanRule> rules;
  final String day;
  final List<String> kept;
  final bool loaded;

  List<PlanRule> of(PlanKind k) => rules.where((r) => r.kind == k).toList();
  int get keptCount => rules.where((r) => kept.contains(r.id)).length;
  bool isKept(String id) => kept.contains(id);

  Plan copyWith({List<PlanRule>? rules, String? day, List<String>? kept, bool? loaded}) =>
      Plan(rules: rules ?? this.rules, day: day ?? this.day, kept: kept ?? this.kept, loaded: loaded ?? this.loaded);

  Map<String, Object?> toJson() => {'rules': [for (final r in rules) r.toJson()], 'day': day, 'kept': kept};
}

/// A starting plan so the room is never empty; every rule can be changed.
const _starter = [
  PlanRule(id: 'm1', kind: PlanKind.more, title: 'Morning walk', icon: 'walk'),
  PlanRule(id: 'm2', kind: PlanKind.more, title: 'Drink water first', icon: 'water'),
  PlanRule(id: 'm3', kind: PlanKind.more, title: '10-minute stretch', icon: 'stretch'),
  PlanRule(id: 's1', kind: PlanKind.skip, title: 'Sugary drinks', icon: 'drink'),
  PlanRule(id: 's2', kind: PlanKind.skip, title: 'Fast food', icon: 'fastfood'),
  PlanRule(id: 's3', kind: PlanKind.skip, title: 'Late-night snacks', icon: 'night'),
];

class PlanNotifier extends Notifier<Plan> {
  static const _key = 'bloom.plan.v1';

  @override
  Plan build() {
    final today = dayKey(DateTime.now());
    _load(today);
    return Plan(rules: _starter, day: today, kept: const []);
  }

  Future<void> _load(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      state = state.copyWith(loaded: true);
      return;
    }
    final j = jsonDecode(raw) as Map<String, Object?>;
    final rules = [for (final r in (j['rules'] as List? ?? const [])) PlanRule.fromJson((r as Map).cast<String, Object?>())];
    final sameDay = j['day'] == today;
    state = Plan(rules: rules, day: today, kept: sameDay ? ((j['kept'] as List?)?.cast<String>() ?? const []) : const [], loaded: true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// Ticks or unticks a rule for today and moves paws with it.
  bool toggle(String id) {
    final on = !state.isKept(id);
    state = state.copyWith(kept: on ? [...state.kept, id] : (state.kept.where((k) => k != id).toList()));
    ref.read(todayProvider.notifier).addPaws(on ? kPawsPerRule : -kPawsPerRule);
    _save();
    return on;
  }

  bool canAdd(PlanKind k) => state.of(k).length < kMaxRules;

  void add(PlanKind kind, String title, String icon) {
    if (!canAdd(kind)) return;
    final id = '${kind.name}-${DateTime.now().microsecondsSinceEpoch}';
    state = state.copyWith(rules: [...state.rules, PlanRule(id: id, kind: kind, title: title.trim(), icon: icon)]);
    _save();
  }

  void update(PlanRule rule) {
    state = state.copyWith(rules: [for (final r in state.rules) r.id == rule.id ? rule : r]);
    _save();
  }

  /// Removes a rule; returns where it was so it can be put back.
  int remove(String id) {
    final i = state.rules.indexWhere((r) => r.id == id);
    final wasKept = state.isKept(id);
    state = state.copyWith(rules: state.rules.where((r) => r.id != id).toList(), kept: state.kept.where((k) => k != id).toList());
    if (wasKept) ref.read(todayProvider.notifier).addPaws(-kPawsPerRule);
    _save();
    return i;
  }

  void restore(PlanRule rule, int index) {
    final list = [...state.rules]..insert(index.clamp(0, state.rules.length), rule);
    state = state.copyWith(rules: list);
    _save();
  }
}

final planProvider = NotifierProvider<PlanNotifier, Plan>(PlanNotifier.new);
