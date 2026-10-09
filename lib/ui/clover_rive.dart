import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;


import '../data/coat.dart';
import '../data/exercises.dart';
import '../data/journal.dart';
import 'clover_scene.dart';

/// Which Rive renderer draws Clover and her scenes. Flutter's canvas measured
/// about 5x cheaper per frame than Rive's own renderer on a Xiaomi 13 (UI
/// 1 ms vs 5.5 ms, raster 1.8 ms vs 7 ms) with identical output, so it's the
/// default. `--dart-define=RIVE_FACTORY=rive` switches back for comparison.
final rive.Factory riveFactory = const String.fromEnvironment('RIVE_FACTORY', defaultValue: 'flutter') == 'rive' ? rive.Factory.rive : rive.Factory.flutter;

/// What Clover is doing. The values match the `action` input of `CloverSM`.
enum CloverAction {
  rest(0),
  march(1),
  squat(2),
  reach(3),
  hop(4),
  cheer(5),
  sad(6),

  /// Today's roaming Clover (new rig). Each arrives after 2 s offscreen, walks in, then loops:
  /// thinking (default), sad (missed yesterday), proud (day complete).
  todayThink(7),
  todaySad(8),
  todayProud(9),

  /// The gym (Shop tab): she comes in through the garage door and loops jumping jacks.
  gymJacks(10),

  /// The balcony (Plan tab): she comes out of the house with her watering can and waters the white
  /// flowers, then the lavender, then strolls back (a 10 s loop).
  balconyWater(11),

  /// The hallway (Progress tab): she walks in and daydreams under the next empty milestone frame
  /// (frames 2-5), or admires the finished gallery once every milestone is reached.
  hallGaze2(13),
  hallGaze3(14),
  hallGaze4(15),
  hallGaze5(16),
  hallDone(17),

  /// The bedroom (Profile tab): she walks in and tidies her bookshelf.
  bedroomTidy(18),

  /// Today, every visit: she's already stretched out on the sofa, and 2 s in gives you a lazy
  /// half-lidded glance. A first tap stirs her (the same look, held); a second tickles her: she giggles,
  /// hops off and walks to the middle of the rug, where the Today moods (7-9) carry on.
  todayLazy(19),
  todayStir(20),
  todayGetUp(21),

  /// Session moves, done with you (each loops until the action changes). In the living room: chair squats,
  /// "wall" push-ups against your phone's glass, a one-song dance, arm circles.
  exSquat(22),
  exWallPush(23),
  exDance(24),
  exArmCircles(25),

  /// In the bedroom: a morning stretch; glute bridges and dead bugs on her mat (she unrolls it and lies down first).
  exStretch(26),
  exBridge(27),
  exDeadBug(28),

  /// In the garage gym, with the gear you own: rope hops, skater steps, curls and overhead presses (dumbbells),
  /// kettlebell swings and goblet squats, the treadmill (a walk, and uphill), and the wall bar (she leaps up to hang,
  /// or to raise her knees).
  exRopeHops(29),
  exSkater(30),
  exCurls(31),
  exPress(32),
  exSwings(33),
  exGoblet(34),
  exTreadWalk(35),
  exIncline(36),
  exHang(37),
  exKneeRaise(38);

  /// How long [todayGetUp] takes, from the tickle to standing on the rug.
  static const getUpTime = Duration(milliseconds: 4500);

  /// The hallway action for the next milestone frame ([next] is its index, 1-4), or the
  /// finished gallery when there is none.
  static CloverAction hallFor(int? next) => switch (next) {
        1 => hallGaze2,
        2 => hallGaze3,
        3 => hallGaze4,
        4 => hallGaze5,
        _ => hallDone,
      };

  const CloverAction(this.value);
  final int value;
}

/// The move Clover mirrors for an exercise.
CloverAction actionFor(Exercise ex) => switch (ex.id) {
      'squats' || 'goblet' || 'swings' || 'glute_bridge' => CloverAction.squat,
      'stretch' || 'arm_circles' || 'press' || 'curls' || 'hangs' || 'wall_pushups' || 'dead_bug' => CloverAction.reach,
      'rope_hops' || 'skater' || 'calf_raises' || 'dance' => CloverAction.hop,
      _ => CloverAction.march,
    };

/// Clover on her own, without a room: the painted CloverRig from assets/rive/clover_rig.riv (the same
/// rig the rooms nest). Breathing, blinking and tail sway always run underneath; [action] plays a move
/// on top, [eyesOpen] is the "Ready?" look, and [bodyMass] (100 = softest) widens only the bean.
class CloverRive extends StatefulWidget {
  const CloverRive({super.key, this.action = CloverAction.rest, this.bodyMass = 60, this.eyesOpen = false, this.fit = rive.Fit.contain, this.alignment = Alignment.bottomCenter});
  final CloverAction action;
  final double bodyMass;
  final bool eyesOpen;
  final rive.Fit fit;
  final Alignment alignment;

  /// Loads the file once for the whole app. Call [init] at startup.
  static bool _nativeReady = false;

  /// Whether Rive's native runtime loaded (false in widget tests).
  static bool get nativeReady => _nativeReady;

  static Future<void> init() async {
    try {
      await rive.RiveNative.init();
      _nativeReady = true;
    } catch (e) {
      debugPrint('Rive: native runtime unavailable: $e');
    }
  }

  /// Decodes the Rive files ahead of time so opening a Clover screen doesn't stall.
  static void preload() {
    if (!_nativeReady) return;
    _load();
    CloverScene.preloadAll();
  }

  static final _files = <Coat, Future<rive.File?>>{};

  /// Clover's own file, with the chosen cat's pieces (only the one in use stays loaded).
  static Future<rive.File?> _load() {
    final coat = Coat.current.value;
    for (final c in [..._files.keys]) {
      if (c != coat) _files.remove(c)?.then((f) => f?.dispose());
    }
    return _files[coat] ??= coat.open('assets/rive/clover_rig.riv', riveFactory);
  }

  @override
  State<CloverRive> createState() => _CloverRiveState();
}

class _CloverRiveState extends State<CloverRive> {
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _vm;
  rive.ViewModelInstanceNumber? _action, _mass;
  rive.ViewModelInstanceBoolean? _eyes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Widget tests can't capture Rive's native drawing; show the flat
    // stand-in there so layouts can still be checked.
    if (!CloverRive._nativeReady || Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() => _failed = true);
      return;
    }
    try {
      final file = await CloverRive._load();
      if (file == null || !mounted) return;
      final c = rive.RiveWidgetController(file, artboardSelector: rive.ArtboardSelector.byName('CloverRig'), stateMachineSelector: rive.StateMachineSelector.byDefault());
      final vm = c.dataBind(rive.DataBind.auto());
      setState(() {
        _controller = c;
        _vm = vm;
        _action = vm.number('action');
        _mass = vm.number('bodyMass');
        _eyes = vm.boolean('eyesOpen');
      });
      _push();
    } catch (e) {
      debugPrint('Rive: could not load Clover: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  /// The rig has no squat, reach, hop or standing sad of its own yet: those play as a march (moving
  /// along with you) or her rest.
  static CloverAction _onRig(CloverAction a) => switch (a) {
        CloverAction.squat || CloverAction.reach || CloverAction.hop => CloverAction.march,
        CloverAction.sad => CloverAction.rest,
        _ => a,
      };

  void _push() {
    _action?.value = _onRig(widget.action).value.toDouble();
    _mass?.value = widget.bodyMass.clamp(0, 100).toDouble();
    _eyes?.value = widget.eyesOpen;
  }

  @override
  void didUpdateWidget(CloverRive old) {
    super.didUpdateWidget(old);
    _push();
  }

  @override
  void dispose() {
    _action?.dispose();
    _mass?.dispose();
    _eyes?.dispose();
    _vm?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed) {
      return CloverStill(alignment: widget.alignment);
    }
    if (c == null) return const SizedBox.expand();
    return rive.RiveWidget(controller: c, fit: widget.fit, alignment: widget.alignment);
  }
}

/// Clover standing at rest, as a picture: where Rive can't draw (widget tests, a failed load).
class CloverStill extends StatelessWidget {
  const CloverStill({super.key, this.alignment = Alignment.bottomCenter});
  final Alignment alignment;

  static const asset = 'assets/widget/widget_clover_rest.png';

  @override
  Widget build(BuildContext context) => Image.asset(asset, fit: BoxFit.contain, alignment: alignment);
}

/// [CloverRive] at her current shape, which follows the effort put in.
class LiveClover extends ConsumerWidget {
  const LiveClover({super.key, this.action = CloverAction.rest, this.eyesOpen = false});
  final CloverAction action;
  final bool eyesOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CloverRive(action: action, eyesOpen: eyesOpen, bodyMass: ref.watch(journalProvider.select((j) => j.bodyMass)));
}
