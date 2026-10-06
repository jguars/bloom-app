import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;

import '../data/exercises.dart';
import '../data/journal.dart';
import 'clover_mini.dart';

/// What Clover is doing. The values match the `action` input of `CloverSM`.
enum CloverAction {
  rest(0),
  march(1),
  squat(2),
  reach(3),
  hop(4),
  cheer(5),
  sad(6);

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

/// The live Clover from assets/rive/clover.riv: breathing, blinking and tail
/// sway always run underneath; [action] plays a move on top, [eyesOpen] is
/// the "Ready?" look, and [bodyMass] (100 = softest) widens only the bean.
class CloverRive extends StatefulWidget {
  const CloverRive({super.key, this.action = CloverAction.rest, this.bodyMass = 60, this.eyesOpen = false, this.fit = rive.Fit.contain, this.alignment = Alignment.bottomCenter});
  final CloverAction action;
  final double bodyMass;
  final bool eyesOpen;
  final rive.Fit fit;
  final Alignment alignment;

  /// Loads the file once for the whole app. Call [init] at startup.
  static Future<rive.File?>? _file;
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

  static Future<rive.File?> _load() => _file ??= rive.File.asset(
        'assets/rive/clover.riv',
        riveFactory: rive.Factory.rive,
      );

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
      final c = rive.RiveWidgetController(file, artboardSelector: rive.ArtboardSelector.byName('Clover'), stateMachineSelector: rive.StateMachineSelector.byName('CloverSM'));
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

  void _push() {
    _action?.value = widget.action.value.toDouble();
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
      // Same footprint as the artboard (600×700, feet at y = 620).
      return LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight.isFinite ? box.maxHeight : 160.0;
        return Stack(children: [
          Positioned(left: 0, right: 0, bottom: h * 80 / 700, child: Center(child: CloverMini(bodyMass: widget.bodyMass, size: h * .63))),
        ]);
      });
    }
    if (c == null) return const SizedBox.expand();
    return rive.RiveWidget(controller: c, fit: widget.fit, alignment: widget.alignment);
  }
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
