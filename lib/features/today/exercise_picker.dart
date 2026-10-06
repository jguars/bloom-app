import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/theme.dart';
import '../../data/equipment.dart';
import '../../data/exercises.dart';
import '../../data/today.dart';
import '../../ui/clover_rive.dart';
import '../../ui/paw.dart';
import '../../ui/room_frame.dart';

/// "Pick a move": every exercise in one scrolling list. Bodyweight moves and
/// moves from owned gear can be picked; the rest show which gear unlocks them.
/// Returns the chosen move, already set as Today's current one so finishing
/// it credits the right paws.
Future<Exercise?> showExercisePicker(BuildContext context, WidgetRef ref) async {
  final ex = await showBloomSheet<Exercise>(context, (context) => const _ExercisePicker());
  if (ex != null) ref.read(todayProvider.notifier).pickExercise(ex);
  return ex;
}

class _ExercisePicker extends ConsumerWidget {
  const _ExercisePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(todayProvider);
    final open = [...dailyExercises, ...gearExercises.where((e) => s.owns(e.equipment!))];
    final locked = gearExercises.where((e) => !s.owns(e.equipment!)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Pick a move', style: BloomText.title),
      Text('Clover will do it with you.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .62),
        child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
          for (final e in open) _MoveRow(ex: e, onTap: () {
            Feel.selectionClick();
            Navigator.of(context).pop(e);
          }),
          if (locked.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 6), child: Text('UNLOCK IN THE SHOP', style: BloomText.label)),
            for (final e in locked) _MoveRow(ex: e, lockedBy: equipmentById(e.equipment!).name),
          ],
        ]),
      ),
    ]);
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.ex, this.onTap, this.lockedBy});
  final Exercise ex;
  final VoidCallback? onTap;
  final String? lockedBy;

  static String _moveName(CloverAction a) => switch (a) {
        CloverAction.march => 'March',
        CloverAction.squat => 'Squat',
        CloverAction.reach => 'Reach',
        CloverAction.hop => 'Hop',
        _ => a.name,
      };

  @override
  Widget build(BuildContext context) {
    final locked = lockedBy != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: locked ? BloomColors.paperSunk : BloomColors.surface,
        borderRadius: BorderRadius.circular(BloomSpace.rLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(BloomSpace.rLg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(BloomSpace.rLg), border: Border.all(color: BloomColors.line)),
            child: Opacity(
              opacity: locked ? .55 : 1,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ex.name, style: BloomText.headline.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(locked ? 'Needs the ${lockedBy!.toLowerCase()}' : ex.meta, style: BloomText.caption),
                  ]),
                ),
                // Which of Clover's animations plays, so every one is easy to try.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                  child: Text(_moveName(actionFor(ex)), style: BloomText.label.copyWith(color: BloomColors.forest, letterSpacing: .4)),
                ),
                const SizedBox(width: 10),
                if (locked)
                  const SizedBox(width: 42, child: Icon(Icons.lock_outline_rounded, size: 20, color: BloomColors.inkMuted))
                else ...[
                  const PawIcon(size: 16),
                  // Fixed width keeps the tags lined up for 1- and 2-digit paws.
                  SizedBox(width: 26, child: Text('${ex.paws}', textAlign: TextAlign.right, style: BloomText.number.copyWith(fontSize: 15))),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
