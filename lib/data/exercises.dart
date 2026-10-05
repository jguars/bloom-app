import 'equipment.dart';

/// One move the user and Clover do together.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.cues,
    required this.seconds,
    required this.effort,
    this.strains = const {},
    this.equipment,
  });

  final String id;
  final String name;

  /// Coaching lines Clover says during the session, in order.
  final List<String> cues;
  final int seconds;

  /// Effort points. Clover's shape follows total effort.
  final double effort;

  /// Body parts it loads; skipped for users who asked to go easy on them.
  final Set<String> strains;

  /// Gear id this needs, or null for bodyweight moves.
  final String? equipment;

  /// Ten paws per effort point (same economy as Avelo).
  int get paws => (effort * 10).round().clamp(5, 100);

  String get effortWord => effort <= 0.5
      ? 'light'
      : effort <= 1
          ? 'light'
          : effort <= 1.5
              ? 'medium'
              : 'brisk';

  String get minutesText {
    final m = (seconds / 60).ceil();
    return '$m min';
  }

  String get meta => '$minutesText · $effortWord';
}

/// Bodyweight moves, always available. Ported from Avelo's dailyExercises.
const dailyExercises = <Exercise>[
  Exercise(id: 'march', name: 'March in place', seconds: 120, effort: 1, cues: [
    'Knees up! Like this!',
    'Swing those arms!',
    'You’re doing great!',
    'Last stretch, together!',
  ]),
  Exercise(id: 'squats', name: 'Chair squats', seconds: 60, effort: 1, strains: {'knees'}, cues: [
    'Sit back like there’s a chair.',
    'And stand tall!',
    'Slow and steady.',
    'Two more with me!',
  ]),
  Exercise(id: 'wall_pushups', name: 'Wall push-ups', seconds: 45, effort: 1, strains: {'wrists'}, cues: [
    'Hands on the wall.',
    'Chest in… and push!',
    'Body nice and straight.',
    'Almost there!',
  ]),
  Exercise(id: 'walk', name: 'Brisk walk', seconds: 600, effort: 2, cues: [
    'Talking pace, not racing.',
    'Arms swinging!',
    'Look at that sky.',
    'Home stretch!',
  ]),
  Exercise(id: 'stretch', name: 'Morning stretch', seconds: 90, effort: 0.5, cues: [
    'Reach up high!',
    'Lean to the side…',
    'Roll those shoulders.',
    'Ahh, that’s nice.',
  ]),
  Exercise(id: 'dance', name: 'One-song dance', seconds: 180, effort: 1.5, cues: [
    'Put on a song you love!',
    'Move however feels good.',
    'Wiggle! I’m wiggling!',
    'Big finish!',
  ]),
  Exercise(id: 'arm_circles', name: 'Arm circles', seconds: 60, effort: 0.5, cues: [
    'Small circles forward.',
    'Now bigger!',
    'And backwards.',
    'Shake them out!',
  ]),
  Exercise(id: 'calf_raises', name: 'Calf raises', seconds: 45, effort: 0.5, cues: [
    'Up on your toes…',
    'Pause at the top.',
    'Slowly down.',
    'Tall cat, tall you!',
  ]),
  Exercise(id: 'stairs', name: 'Stair climb', seconds: 120, effort: 1.5, strains: {'knees'}, cues: [
    'One flight, slow and steady.',
    'Hold the rail.',
    'Breathe…',
    'Top of the world!',
  ]),
  Exercise(id: 'evening_walk', name: 'Evening stroll', seconds: 900, effort: 2, cues: [
    'Let’s see the sunset.',
    'Easy pace.',
    'Wave at the neighbours!',
    'Nearly home.',
  ]),
];

/// Today's picks: gear moves the user owns come first (they pay more), then
/// the bodyweight basics, up to ten, in a stable order for the day so swapping
/// feels like browsing her list, not a dice roll.
List<Exercise> picksFor(String day, {Set<String> owned = const {}, Set<String> limits = const {}}) {
  final gear = gearExercises.where((e) => owned.contains(e.equipment)).toList();
  final safe = [...gear, ...dailyExercises].where((e) => e.strains.intersection(limits).isEmpty).toList();
  final list = safe.length >= 3 ? safe : [...gear, ...dailyExercises];
  final seed = day.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
  final basics = list.where((e) => e.equipment == null).toList();
  final shift = basics.isEmpty ? 0 : seed % basics.length;
  final rotated = [...basics.skip(shift), ...basics.take(shift)];
  return [...list.where((e) => e.equipment != null), ...rotated].take(10).toList();
}

/// Finds any move by id.
Exercise? exerciseById(String id) {
  for (final e in [...gearExercises, ...dailyExercises]) {
    if (e.id == id) return e;
  }
  return null;
}
