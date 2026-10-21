import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/equipment.dart';
import '../../data/exercises.dart';
import '../../ui/bits.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../today/flow.dart';
import '../today/ready_screen.dart' show RoundButton;
import '../today/session_screen.dart';

/// A test-build-only screen for inspecting every move: each exercise, gear or not, opens its session in preview,
/// which plays Clover's move in its room but saves nothing (no move logged, no paws, no gear needed).
/// Only in builds made with `--dart-define=LAB=true`; otherwise the entry to it is compiled out.
class MoveLabScreen extends StatelessWidget {
  const MoveLabScreen({super.key});

  static const enabled = bool.fromEnvironment('LAB');

  static String _room(Exercise ex) => switch (sessionRoom(ex)?.$1) {
        CloverScene.today => 'Living room',
        CloverScene.profile => 'Bedroom',
        CloverScene.gym => 'Garage gym',
        _ => 'Park',
      };

  @override
  Widget build(BuildContext context) {
    final all = [...dailyExercises, ...gearExercises];
    final rooms = <String, List<Exercise>>{};
    for (final ex in all) {
      rooms.putIfAbsent(_room(ex), () => []).add(ex);
    }
    String fmt(int s) => s >= 60 ? '${s ~/ 60} min${s % 60 > 0 ? ' ${s % 60} s' : ''}' : '$s s';
    return Scaffold(
      backgroundColor: BloomColors.paper,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 32),
        children: [
          Row(children: [
            RoundButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 12),
            Text('Move lab', style: BloomText.title),
          ]),
          const SizedBox(height: 8),
          Text('Test build only. Every move plays in its room; nothing is saved and no gear is needed.', style: BloomText.caption),
          for (final MapEntry(key: room, value: moves) in rooms.entries) ...[
            const SizedBox(height: 20),
            Eyebrow('$room · ${moves.length}'),
            const SizedBox(height: 10),
            GroupCard(children: [
              for (final (i, ex) in moves.indexed)
                GroupRow(
                  title: ex.name,
                  caption: [
                    if (ex.equipment != null) equipmentById(ex.equipment!).name,
                    fmt(ex.seconds),
                    'action ${sessionRoom(ex)?.$2.value ?? actionFor(ex).value}',
                  ].join(' · '),
                  onTap: () => Navigator.of(context).push(bloomRoute(SessionScreen(ex: ex, preview: true))),
                  last: i == moves.length - 1,
                ),
            ]),
          ],
        ],
      ),
    );
  }
}
