import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'plan.dart';

/// How a food or drink sits with the user's plan. Never "bad": the words are
/// "a good pick", "fine in moderation" and "on your skip list".
enum FoodFit { good, okay, skip }

class FoodVerdict {
  const FoodVerdict({required this.name, required this.fit, required this.note, this.rule, this.demo = false});
  final String name;
  final FoodFit fit;

  /// One kind sentence from Clover.
  final String note;

  /// The skip rule it matches, if any.
  final PlanRule? rule;

  /// A made-up result shown while no checker is connected.
  final bool demo;
}

class FoodCheckNotConnected implements Exception {
  const FoodCheckNotConnected();
}

/// Looks at a photo and says how it fits the plan. The app ships with
/// [NotConnectedFoodChecker]; override [foodCheckerProvider] in main() with a
/// real one (a backend that calls a vision model) when it exists.
abstract class FoodChecker {
  Future<FoodVerdict> check(Uint8List photo, List<PlanRule> rules);
}

class NotConnectedFoodChecker implements FoodChecker {
  const NotConnectedFoodChecker();
  @override
  Future<FoodVerdict> check(Uint8List photo, List<PlanRule> rules) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    throw const FoodCheckNotConnected();
  }
}

final foodCheckerProvider = Provider<FoodChecker>((ref) => const NotConnectedFoodChecker());

/// What a result looks like, for the "see an example" button.
FoodVerdict demoVerdict(List<PlanRule> rules) {
  final sugary = rules.where((r) => r.kind == PlanKind.skip && r.title.toLowerCase().contains('sugar')).firstOrNull;
  return FoodVerdict(
    name: 'Fizzy orange soda',
    fit: sugary != null ? FoodFit.skip : FoodFit.okay,
    note: 'Lots of sugar in there. How about sparkling water with a slice of orange? I’ll have one too.',
    rule: sugary,
    demo: true,
  );
}
