import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plans on the paywall. Prices are placeholders until store products exist.
enum PremiumPlan {
  yearly('Yearly', 39.99),
  monthly('Monthly', 9.99);

  const PremiumPlan(this.label, this.price);
  final String label;
  final double price;

  String get priceText => '\$${price.toStringAsFixed(2)}';
}

/// Days of free trial on the yearly plan.
const kTrialDays = 7;

class Premium {
  const Premium({this.active = false, this.plan, this.trialEnds, this.test = false});
  final bool active;
  final PremiumPlan? plan;
  final DateTime? trialEnds;

  /// Unlocked by a test purchase: there is no store connected yet.
  final bool test;

  Map<String, Object?> toJson() => {'active': active, 'plan': plan?.name, 'trialEnds': trialEnds?.toIso8601String(), 'test': test};

  factory Premium.fromJson(Map<String, Object?> j) => Premium(
        active: j['active'] as bool? ?? false,
        plan: PremiumPlan.values.asNameMap()[j['plan']],
        trialEnds: j['trialEnds'] == null ? null : DateTime.parse(j['trialEnds'] as String),
        test: j['test'] as bool? ?? false,
      );
}

class PremiumNotifier extends Notifier<Premium> {
  static const _key = 'bloom.premium.v1';

  @override
  Premium build() {
    _load();
    return const Premium();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) state = Premium.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// Test purchase: unlocks Plus with no store and no payment.
  Future<void> startTest(PremiumPlan plan) async {
    state = Premium(active: true, plan: plan, trialEnds: plan == PremiumPlan.yearly ? DateTime.now().add(const Duration(days: kTrialDays)) : null, test: true);
    await _save();
  }

  /// Debug: back to free.
  Future<void> reset() async {
    state = const Premium();
    await _save();
  }
}

final premiumProvider = NotifierProvider<PremiumNotifier, Premium>(PremiumNotifier.new);
