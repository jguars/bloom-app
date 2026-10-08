import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/motion.dart';
import '../app/shell.dart';

/// The roaming Clover's visits to a room. Each visit (opening the tab, or calling [startVisit] for a new
/// mood) restarts her arrival: the room starts empty, she walks in at 2 s and reaches her spot at ~5.3 s
/// (the Rive Arrive* timelines). [arrived] turns on then, so her line and reactions wait for her.
/// Key the room's CloverSceneView with [visit] so each visit replays the arrival from the start.
mixin RoomVisit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const arriveAfter = Duration(milliseconds: 5300);

  /// The tab this screen lives in.
  Room get visitRoom;

  int visit = 0;
  bool arrived = false;
  Timer? _arriving;
  bool _started = false;

  void startVisit() {
    visit++;
    arrived = false;
    _arriving?.cancel();
    _arriving = Timer(arriveAfter, () {
      if (mounted) setState(() => arrived = true);
    });
  }

  /// Whether this room's tab is the one on show. Hidden rooms drop their live scene (it holds the
  /// decoded room and a running animation); each visit rebuilds it from the empty room anyway.
  bool get onShow => ref.watch(roomProvider) == visitRoom || !ShellScope.of(context);

  /// Call at the top of build: starts the first visit and a new one each time the tab is opened again.
  void watchVisits() {
    if (!_started) {
      _started = true;
      startVisit();
    }
    ref.listen(roomProvider, (prev, next) {
      if (next == visitRoom && prev != visitRoom) setState(startVisit);
    });
  }

  @override
  void dispose() {
    _arriving?.cancel();
    super.dispose();
  }
}

/// Pops its child in as Clover arrives in the room (and hides it at once when a new visit starts).
class ArrivedPop extends StatelessWidget {
  const ArrivedPop({super.key, required this.shown, required this.child, this.alignment = Alignment.bottomLeft});
  final bool shown;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: Duration(milliseconds: shown ? 260 : 0),
        child: AnimatedScale(
          scale: shown ? 1 : .6,
          duration: Duration(milliseconds: shown ? 520 : 0),
          curve: BloomMotion.pop,
          alignment: alignment,
          child: child,
        ),
      );
}
