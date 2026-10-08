import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:rive/rive.dart' as rive;


import '../app/idle.dart';
import '../app/theme.dart';
import '../data/coat.dart';
import '../data/wardrobe.dart';
import 'clover_mini.dart';
import 'clover_rive.dart';

/// The painted Clover rig inside one of her Rive scenes. Each scene is its own
/// artboard (exported with the CloverRig nested in it) and shares CloverRigVM:
/// `walking` + `action` (March, Cheer, the rooms) and `eyesOpen` (Ready).
enum CloverScene {
  /// She walks in place while the park scrolls at her stride (session, marching moves).
  march('assets/rive/march_scene.riv', 'MarchScene', 'assets/scenes/march-empty.jpg'),

  /// Close-up on the living-room rug: eyes pop open, fist pump, eager bounce.
  ready('assets/rive/ready_scene.riv', 'ReadyScene', 'assets/scenes/ready-empty.jpg'),

  /// The back garden at golden hour: she laughs, leaps with her arms in a V, then keeps hopping.
  cheer('assets/rive/cheer_scene.riv', 'CheerScene', 'assets/scenes/celebrate-empty.jpg'),

  /// The living room (Today tab). She isn't home at first; after 2 s she walks in and thinks,
  /// mopes or beams (see [CloverAction.todayThink]). Centred like the room art, so RoomLight lines up.
  today('assets/rive/today_scene.riv', 'TodayScene', 'assets/scenes/living-empty.jpg', Alignment.center),

  /// The garage gym (Shop tab). Empty at first; after 2 s she comes in through the garage door on the
  /// right and does jumping jacks ([CloverAction.gymJacks]) between the kettlebell shelf and the bike.
  gym('assets/rive/gym_scene.riv', 'GymScene', 'assets/scenes/garage-empty.jpg', Alignment.center, Offset(690, 485), Size(1100, 841)),

  /// The balcony (Plan tab). After 2 s she comes out of the house on the right with her watering can
  /// and waters pot to pot ([CloverAction.balconyWater]). Framed a little left so the lavender shows;
  /// her line hangs over her first spot, by the white flowers.
  plan('assets/rive/plan_scene.riv', 'PlanScene', 'assets/scenes/balcony-empty.jpg', Alignment(-.3, 0), Offset(560, 435), Size(1100, 842)),

  /// The hallway (Progress tab). Her milestone portraits hang in the frames (the app paints them, see
  /// [hallFrames]); after 2 s she walks in from the left and daydreams under the next empty one.
  /// Framed left of centre so the door and all five frames show. Her head depends on the frame, so the
  /// Progress room passes it in.
  progress('assets/rive/progress_scene.riv', 'ProgressScene', 'assets/scenes/hallway-empty.jpg', Alignment(-.6, 0), Offset(512, 455), Size(1100, 842)),

  /// The bedroom (Profile tab). After 2 s she walks in from the left and tidies her bookshelf. The art is
  /// padded (wall above, floor below, wall on the right) and framed right of centre, so the shelf on the
  /// left and the round window and lamp on the right sit evenly in view. The window's sky is live (BedroomWindow).
  profile('assets/rive/profile_scene.riv', 'ProfileScene', 'assets/scenes/bedroom-empty.jpg', Alignment(.82, 0), Offset(560, 517), Size(1160, 942));

  /// The hallway's five frame openings (the mats inside the wood), in artboard units.
  static const hallFrames = [
    Rect.fromLTRB(214, 214, 293, 305),
    Rect.fromLTRB(347, 214, 424, 305),
    Rect.fromLTRB(475, 214, 551, 305),
    Rect.fromLTRB(601, 214, 672, 305),
    Rect.fromLTRB(721, 214, 790, 305),
  ];

  const CloverScene(this.asset, this.artboard, this.fallback, [this.alignment = Alignment.bottomCenter, this.head, this.size]);
  final String asset, artboard;

  /// Rooms: the top of her head once she's on her spot, in the artboard's units, and the artboard's size,
  /// so the room can hang her speech bubble there.
  final Offset? head;
  final Size? size;

  /// How much the art is scaled when it fills a [box] (Fit.cover).
  double scaleIn(Size box) => math.max(box.width / size!.width, box.height / size!.height);

  /// A point of the art (artboard units) on screen when the art fills a [box] (Fit.cover at [alignment]).
  Offset toScreen(Offset p, Size box) {
    final art = size!, k = scaleIn(box);
    final dx = (box.width - art.width * k) * (alignment.x + 1) / 2, dy = (box.height - art.height * k) * (alignment.y + 1) / 2;
    return Offset(dx + p.dx * k, dy + p.dy * k);
  }

  /// [head] (or [at], when her spot varies) on screen when the art fills a [box].
  Offset headIn(Size box, [Offset? at]) => toScreen(at ?? head!, box);

  /// How the scene's art is anchored when cropped to fill the screen.
  final Alignment alignment;

  /// Shown under widget tests, where Rive can't draw.
  final String fallback;

  // Each scene holds its painted room and the whole rig, decoded: tens of MB. Only the ones on show
  // stay loaded, plus the [_keep] most recently closed (so flipping between two tabs is instant);
  // older ones are freed.
  static const _keep = 2;
  static final _files = <(CloverScene, Coat), Future<rive.File?>>{};
  static final _users = <(CloverScene, Coat), int>{};
  static final _recent = <(CloverScene, Coat)>[];

  /// This scene, drawn with [coat]'s cat (by default the one chosen now).
  Future<rive.File?> load([Coat? coat]) {
    final c = coat ?? Coat.current.value;
    return _files[(this, c)] ??= c.open(asset, riveFactory);
  }

  /// A view starts showing this scene with [coat]: load it (or reuse it) and keep it while in use.
  Future<rive.File?> acquire(Coat coat) {
    final k = (this, coat);
    _users[k] = (_users[k] ?? 0) + 1;
    _recent.remove(k);
    return load(coat);
  }

  /// A view stopped showing it; free the oldest scenes nobody is showing.
  void release(Coat coat) {
    final k = (this, coat);
    final n = (_users[k] ?? 1) - 1;
    if (n > 0) {
      _users[k] = n;
      return;
    }
    _users.remove(k);
    _recent
      ..remove(k)
      ..add(k);
    while (_recent.length > _keep) {
      final old = _recent.removeAt(0);
      _files.remove(old)?.then((f) => f?.dispose());
    }
  }

  /// Decodes the first room shown (Today) ahead of time so opening the app doesn't stall.
  static void preloadAll() => today.load();
}

/// Plays a [CloverScene] filling [height] (anchored per scene, so her feet
/// never crop), fading into the panel below like the other scenes.
class CloverSceneView extends StatefulWidget {
  const CloverSceneView({super.key, required this.scene, required this.height, this.walking = false, this.eyesOpen = false, this.cheering = false, this.action, this.overlay, this.fadeHeight = 48});
  final CloverScene scene;
  final double height;

  /// March: the park scrolls and she marches. Off: the park freezes and she rests.
  final bool walking;

  /// Ready: her eyes and smile open and she plays the intro, then the eager loop.
  final bool eyesOpen;

  /// Cheer: she laughs and leaps, then hops until this turns off.
  final bool cheering;

  /// Plays this action directly (the rooms' activities); overrides walking and cheering.
  final CloverAction? action;

  /// Painted over the art, under the fade (e.g. RoomLight's time-of-day tint).
  final Widget? overlay;
  final double fadeHeight;

  @override
  State<CloverSceneView> createState() => _CloverSceneViewState();
}

class _CloverSceneViewState extends State<CloverSceneView> {
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _vm;
  rive.ViewModelInstanceBoolean? _walking, _eyes;
  rive.ViewModelInstanceNumber? _action;

  /// What she's wearing, one number per slot (see [Worn]).
  final _wear = <OutfitSlot, rive.ViewModelInstanceNumber?>{};
  bool _failed = false;

  /// The cat whose scene file this view holds (see [CloverScene.acquire]); released on dispose, or
  /// when another cat is chosen and the scene reloads with hers.
  Coat? _held;

  @override
  void initState() {
    super.initState();
    Idle.idle.addListener(_onIdle);
    Coat.current.addListener(_onCoat);
    Worn.current.addListener(_dress);
    _start();
  }

  void _onCoat() {
    if (Coat.current.value == _held || _failed) return;
    _drop();
    setState(() {});
    _start();
  }

  /// Lets go of the live scene and its file.
  void _drop() {
    _walking?.dispose();
    _action?.dispose();
    _eyes?.dispose();
    _vm?.dispose();
    _controller?.dispose();
    for (final n in _wear.values) {
      n?.dispose();
    }
    _wear.clear();
    _walking = _action = null;
    _eyes = null;
    _vm = null;
    _controller = null;
    if (_held case final c?) widget.scene.release(c);
    _held = null;
  }

  // Rive's clock ignores TickerMode (and pausing the controller doesn't stop its state machine asking
  // for frames), so when the app goes idle the scene is frozen on a still of its last frame and the
  // live view leaves the tree; a touch puts it back, carrying on where it was.
  final _artKey = GlobalKey();
  ui.Image? _still;

  Future<void> _onIdle() async {
    if (!Idle.idle.value) {
      final old = _still;
      if (old != null) {
        setState(() => _still = null);
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      return;
    }
    final box = _artKey.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || !mounted) return;
    try {
      final img = await box.toImage(pixelRatio: MediaQuery.of(context).devicePixelRatio);
      if (mounted && Idle.idle.value) {
        setState(() => _still = img);
      } else {
        img.dispose();
      }
    } catch (_) {}
  }

  Future<void> _start() async {
    // Widget tests can't capture Rive's native drawing (see CloverRive).
    if (!CloverRive.nativeReady || Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() => _failed = true);
      return;
    }
    try {
      final coat = Coat.current.value;
      final file = await widget.scene.acquire(coat);
      if (!mounted || coat != Coat.current.value) {
        widget.scene.release(coat); // closed, or another cat chosen, while loading
        return;
      }
      _held = coat;
      if (file == null) return;
      final c = rive.RiveWidgetController(file, artboardSelector: rive.ArtboardSelector.byName(widget.scene.artboard), stateMachineSelector: rive.StateMachineSelector.byDefault());
      // The scene and the Clover nested in it share CloverRigVM.
      final vm = c.dataBind(rive.DataBind.auto());
      setState(() {
        _controller = c;
        _vm = vm;
        _walking = vm.boolean('walking');
        _action = vm.number('action');
        _eyes = vm.boolean('eyesOpen');
        for (final slot in OutfitSlot.values) {
          _wear[slot] = vm.number('wear${_rigSlot[slot]}');
        }
      });
      _push();
    } catch (e) {
      debugPrint('Rive: could not load ${widget.scene.artboard}: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _push() {
    _walking?.value = widget.walking;
    final action = widget.action ??
        (widget.walking
            ? CloverAction.march
            : widget.cheering
                ? CloverAction.cheer
                : CloverAction.rest);
    _action?.value = action.value.toDouble();
    _eyes?.value = widget.eyesOpen;
    _dress();
  }

  static const _rigSlot = {OutfitSlot.head: 'Head', OutfitSlot.eyes: 'Eyes', OutfitSlot.neck: 'Neck', OutfitSlot.body: 'Top'};

  void _dress() {
    final worn = Worn.current.value;
    for (final MapEntry(:key, :value) in _wear.entries) {
      value?.value = (worn[key] ?? 0).toDouble();
    }
  }

  @override
  void didUpdateWidget(CloverSceneView old) {
    super.didUpdateWidget(old);
    if (old.walking != widget.walking || old.eyesOpen != widget.eyesOpen || old.cheering != widget.cheering || old.action != widget.action) _push();
  }

  @override
  void dispose() {
    Idle.idle.removeListener(_onIdle);
    Coat.current.removeListener(_onCoat);
    Worn.current.removeListener(_dress);
    _still?.dispose();
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final Widget art;
    if (_failed) {
      art = Stack(fit: StackFit.expand, children: [
        Image.asset(widget.scene.fallback, fit: BoxFit.cover, alignment: widget.scene.alignment),
        Positioned(left: 0, right: 0, bottom: widget.height * .17, child: Center(child: CloverMini(bodyMass: 60, size: widget.height * .3))),
      ]);
    } else if (c == null) {
      art = const ColoredBox(color: Color(0xFFF8F0D9));
    } else {
      final still = _still;
      art = still != null
          ? RawImage(image: still, fit: BoxFit.fill)
          : RepaintBoundary(key: _artKey, child: rive.RiveWidget(controller: c, fit: rive.Fit.cover, alignment: widget.scene.alignment));
    }
    return SizedBox(
      height: widget.height,
      child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
        ClipRect(child: art),
        ?widget.overlay,
        // The fade turns solid a little above the bottom and runs a pixel past it, so no edge of the
        // art (or the artboard behind it) can show as a line where the scene meets the panel.
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          height: widget.fadeHeight + 1,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFBF3), Color(0xB3FFFBF3), BloomColors.surface, BloomColors.surface],
                  stops: [0, .5, .82, 1],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
