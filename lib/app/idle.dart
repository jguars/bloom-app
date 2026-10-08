import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Rests the app's animations when nobody has touched the screen for a while, so an app left open
/// on the table draws nothing (and the phone doesn't warm up). Any touch wakes everything at once.
///
/// [Shell] turns tickers off under it while idle; Clover's Rive scenes (whose clock ignores
/// TickerMode) pause themselves by listening to [idle].
abstract final class Idle {
  static const after = Duration(seconds: 60);
  static final idle = ValueNotifier(false);
  static Timer? _timer;
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _arm();
  }

  static void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent || e is PointerMoveEvent || e is PointerSignalEvent) _arm();
  }

  static void _arm() {
    _timer?.cancel();
    if (idle.value) idle.value = false;
    _timer = Timer(after, () {
      idle.value = true;
    });
  }
}
