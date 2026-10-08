import 'exercises.dart';

/// Anything sold in the Shop for paws. [plus] items (the most advanced and pricey in each aisle)
/// can only be bought with Bloom Plus.
abstract class ShopItem {
  const ShopItem({required this.id, required this.name, required this.price, required this.blurb, this.plus = false});
  final String id;
  final String name;

  /// Cost in paws. Same scale as Avelo: a typical day earns about 50.
  final int price;
  final String blurb;
  final bool plus;
}

/// A piece of home-gym gear, bought with paws in the Shop (the garage).
class Equipment extends ShopItem {
  const Equipment({required super.id, required super.name, required super.price, required super.blurb, super.plus});

  List<Exercise> get unlocks => gearExercises.where((e) => e.equipment == id).toList();
}

const equipmentCatalog = <Equipment>[
  Equipment(id: 'mat', name: 'Yoga mat', price: 60, blurb: 'Floor moves that wake up your core.'),
  Equipment(id: 'rope', name: 'Jump rope', price: 150, blurb: 'Light cardio that gets the heart going.'),
  Equipment(id: 'dumbbells', name: 'Dumbbells', plus: true, price: 280, blurb: 'Strength that makes every day easier.'),
  Equipment(id: 'kettlebell', name: 'Kettlebell', plus: true, price: 450, blurb: 'Whole-body moves, big effort.'),
  Equipment(id: 'treadmill', name: 'Treadmill', plus: true, price: 700, blurb: 'Walk any weather, as long as you like.'),
  Equipment(id: 'bar', name: 'Pull-up bar', plus: true, price: 1000, blurb: 'The crown of her home gym.'),
];

Equipment equipmentById(String id) => equipmentCatalog.firstWhere((e) => e.id == id);

/// Moves that need gear. Worth more effort, so they pay more paws.
const gearExercises = <Exercise>[
  Exercise(id: 'glute_bridge', name: 'Glute bridges', equipment: 'mat', seconds: 60, effort: 1.5, strains: {'back'}, cues: ['Lie back, knees bent.', 'Lift your hips!', 'Squeeze at the top.', 'Slowly down.']),
  Exercise(id: 'dead_bug', name: 'Dead bugs', equipment: 'mat', seconds: 60, effort: 1.5, cues: ['Arms up, knees up.', 'Opposite arm and leg out.', 'Back flat on the mat.', 'Last few!']),
  Exercise(id: 'rope_hops', name: 'Rope hops', equipment: 'rope', seconds: 180, effort: 2, strains: {'knees'}, cues: ['Small hops, soft knees.', 'Find a rhythm!', 'Wrists do the work.', 'Big finish!']),
  Exercise(id: 'skater', name: 'Skater steps', equipment: 'rope', seconds: 240, effort: 2, strains: {'knees'}, cues: ['Step side to side.', 'Swing those arms!', 'Like ice skating!', 'Nearly there!']),
  Exercise(id: 'curls', name: 'Bicep curls', equipment: 'dumbbells', seconds: 90, effort: 2, cues: ['Elbows by your sides.', 'Curl up… and down.', 'Slow on the way down.', 'Strong!']),
  Exercise(id: 'press', name: 'Overhead press', equipment: 'dumbbells', seconds: 90, effort: 2, strains: {'shoulders'}, cues: ['Weights at your shoulders.', 'Press up!', 'Ribs down.', 'Two more!']),
  Exercise(id: 'swings', name: 'Kettlebell swings', equipment: 'kettlebell', seconds: 120, effort: 3, strains: {'back'}, cues: ['Hinge at the hips.', 'Snap them forward!', 'Let it float.', 'Power!']),
  Exercise(id: 'goblet', name: 'Goblet squats', equipment: 'kettlebell', seconds: 120, effort: 2.5, strains: {'knees'}, cues: ['Hold it at your chest.', 'Sit down deep.', 'Drive up!', 'Last ones!']),
  Exercise(id: 'tread_walk', name: 'Treadmill walk', equipment: 'treadmill', seconds: 900, effort: 3, cues: ['Easy pace to start.', 'Pick it up a little.', 'Steady breathing.', 'Cool down.']),
  Exercise(id: 'incline', name: 'Incline walk', equipment: 'treadmill', seconds: 600, effort: 3.5, cues: ['Tilt it up a bit.', 'Push through your heels.', 'Uphill hero!', 'Almost at the top!']),
  Exercise(id: 'hangs', name: 'Bar hangs', equipment: 'bar', seconds: 60, effort: 3, strains: {'shoulders', 'wrists'}, cues: ['Grip the bar.', 'Just hang and breathe.', 'Shoulders down.', 'Let go gently.']),
  Exercise(id: 'knee_raises', name: 'Hanging knee raises', equipment: 'bar', seconds: 60, effort: 3.5, strains: {'shoulders'}, cues: ['Hang tall.', 'Knees up!', 'Slow and controlled.', 'You did it!']),
];
