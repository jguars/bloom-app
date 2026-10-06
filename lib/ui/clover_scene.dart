import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../app/theme.dart';
import 'clover_mini.dart';
import 'clover_rive.dart';

/// The painted Clover rig inside one of her Rive scenes. Each scene is its own
/// artboard (exported with the CloverRig nested in it) and shares CloverRigVM:
/// `walking` + `action` (March) and `eyesOpen` (Ready).
enum CloverScene {
  /// She walks in place while the park scrolls at her stride (session, marching moves).
  march('assets/rive/march_scene.riv', 'MarchScene', 'assets/scenes/march-empty.jpg'),

  /// Close-up on the living-room rug: eyes pop open, fist pump, eager bounce.
  ready('assets/rive/ready_scene.riv', 'ReadyScene', 'assets/scenes/ready-empty.jpg');

  const CloverScene(this.asset, this.artboard, this.fallback);
  final String asset, artboard;

  /// Shown under widget tests, where Rive can't draw.
  final String fallback;

  static final _files = <CloverScene, Future<rive.File?>>{};
  Future<rive.File?> load() => _files[this] ??= rive.File.asset(asset, riveFactory: riveFactory);

  /// Decodes every scene ahead of time so opening one doesn't stall.
  static void preloadAll() {
    for (final s in values) {
      s.load();
    }
  }
}

/// Plays a [CloverScene] filling [height], anchored to the bottom so her feet
/// never crop, fading into the panel below like the other scenes.
class CloverSceneView extends StatefulWidget {
  const CloverSceneView({super.key, required this.scene, required this.height, this.walking = false, this.eyesOpen = false, this.fadeHeight = 48});
  final CloverScene scene;
  final double height;

  /// March: the park scrolls and she marches. Off: the park freezes and she rests.
  final bool walking;

  /// Ready: her eyes and smile open and she plays the intro, then the eager loop.
  final bool eyesOpen;
  final double fadeHeight;

  @override
  State<CloverSceneView> createState() => _CloverSceneViewState();
}

class _CloverSceneViewState extends State<CloverSceneView> {
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _vm;
  rive.ViewModelInstanceBoolean? _walking, _eyes;
  rive.ViewModelInstanceNumber? _action;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Widget tests can't capture Rive's native drawing (see CloverRive).
    if (!CloverRive.nativeReady || Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() => _failed = true);
      return;
    }
    try {
      final file = await widget.scene.load();
      if (file == null || !mounted) return;
      final c = rive.RiveWidgetController(file, artboardSelector: rive.ArtboardSelector.byName(widget.scene.artboard), stateMachineSelector: rive.StateMachineSelector.byDefault());
      // The scene and the Clover nested in it share CloverRigVM.
      final vm = c.dataBind(rive.DataBind.auto());
      setState(() {
        _controller = c;
        _vm = vm;
        _walking = vm.boolean('walking');
        _action = vm.number('action');
        _eyes = vm.boolean('eyesOpen');
      });
      _push();
    } catch (e) {
      debugPrint('Rive: could not load ${widget.scene.artboard}: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _push() {
    _walking?.value = widget.walking;
    _action?.value = (widget.walking ? CloverAction.march : CloverAction.rest).value.toDouble();
    _eyes?.value = widget.eyesOpen;
  }

  @override
  void didUpdateWidget(CloverSceneView old) {
    super.didUpdateWidget(old);
    if (old.walking != widget.walking || old.eyesOpen != widget.eyesOpen) _push();
  }

  @override
  void dispose() {
    _walking?.dispose();
    _action?.dispose();
    _eyes?.dispose();
    _vm?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final Widget art;
    if (_failed) {
      art = Stack(fit: StackFit.expand, children: [
        Image.asset(widget.scene.fallback, fit: BoxFit.cover, alignment: Alignment.bottomCenter),
        Positioned(left: 0, right: 0, bottom: widget.height * .17, child: Center(child: CloverMini(bodyMass: 60, size: widget.height * .3))),
      ]);
    } else if (c == null) {
      art = const ColoredBox(color: Color(0xFFF8F0D9));
    } else {
      art = rive.RiveWidget(controller: c, fit: rive.Fit.cover, alignment: Alignment.bottomCenter);
    }
    return SizedBox(
      height: widget.height,
      child: Stack(fit: StackFit.expand, children: [
        art,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: widget.fadeHeight,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFBF3), BloomColors.surface])),
            ),
          ),
        ),
      ]),
    );
  }
}
