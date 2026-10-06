import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../app/theme.dart';
import 'clover_mini.dart';
import 'clover_rive.dart';

/// Clover marching through the park (assets/rive/march_scene.riv): she walks
/// in place while the park layers scroll right to left at her stride, so it
/// reads as walking. When [walking] is false the park freezes where it is and
/// she eases into her rest pose (still breathing).
///
/// The artboard is 900×1200 with her feet at y = 1025; it's shown with
/// [rive.Fit.cover] anchored to the bottom so the path never crops, then fades
/// into the panel below like the other scenes.
class MarchSceneView extends StatefulWidget {
  const MarchSceneView({super.key, required this.height, this.walking = true, this.fadeHeight = 48});
  final double height;
  final bool walking;
  final double fadeHeight;

  static Future<rive.File?>? _file;
  static Future<rive.File?> _load() => _file ??= rive.File.asset('assets/rive/march_scene.riv', riveFactory: rive.Factory.rive);

  @override
  State<MarchSceneView> createState() => _MarchSceneViewState();
}

class _MarchSceneViewState extends State<MarchSceneView> {
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _vm;
  rive.ViewModelInstanceBoolean? _walking;
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
      final file = await MarchSceneView._load();
      if (file == null || !mounted) return;
      final c = rive.RiveWidgetController(file, artboardSelector: rive.ArtboardSelector.byName('MarchScene'), stateMachineSelector: rive.StateMachineSelector.byDefault());
      // The scene and the Clover nested in it share CloverRigVM.
      final vm = c.dataBind(rive.DataBind.auto());
      setState(() {
        _controller = c;
        _vm = vm;
        _walking = vm.boolean('walking');
        _action = vm.number('action');
      });
      _push();
    } catch (e) {
      debugPrint('Rive: could not load the march scene: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _push() {
    _walking?.value = widget.walking;
    _action?.value = (widget.walking ? CloverAction.march : CloverAction.rest).value.toDouble();
  }

  @override
  void didUpdateWidget(MarchSceneView old) {
    super.didUpdateWidget(old);
    if (old.walking != widget.walking) _push();
  }

  @override
  void dispose() {
    _walking?.dispose();
    _action?.dispose();
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
        Image.asset('assets/scenes/march-empty.jpg', fit: BoxFit.cover, alignment: Alignment.bottomCenter),
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
