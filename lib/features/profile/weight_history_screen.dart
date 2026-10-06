import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/profile.dart';
import '../../data/weight.dart';
import '../../ui/bits.dart';
import '../../ui/weight_chart.dart';

/// Every weigh-in, newest first. Swipe one away to remove it (with undo).
class WeightHistoryScreen extends ConsumerWidget {
  const WeightHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(weightProvider);
    final units = ref.watch(unitsProvider);
    final entries = log.entries.reversed.toList();
    return SubPage(
      from: 'Profile',
      title: 'Weight history',
      children: [
        if (entries.isEmpty)
          BloomCard(child: Text('No weigh-ins yet. Log one from Progress and it shows up here.', style: BloomText.bodyMuted))
        else ...[
          Text(
            log.goalKg == null ? '${entries.length} ${entries.length == 1 ? 'log' : 'logs'}' : '${entries.length} ${entries.length == 1 ? 'log' : 'logs'} · goal ${units.weight(log.goalKg!)}',
            style: BloomText.bodyMuted.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          GroupCard(children: [
            for (var i = 0; i < entries.length; i++) _Entry(entry: entries[i], previous: i + 1 < entries.length ? entries[i + 1] : null, units: units, last: i == entries.length - 1),
          ]),
          const SizedBox(height: 10),
          Text('Swipe left on a weigh-in to remove it.', style: BloomText.caption, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _Entry extends ConsumerWidget {
  const _Entry({required this.entry, required this.previous, required this.units, required this.last});
  final WeightEntry entry;
  final WeightEntry? previous;
  final Units units;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = entry.at;
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final diff = previous == null ? null : entry.kg - previous!.kg;
    return Dismissible(
      key: ObjectKey(entry),
      direction: DismissDirection.endToStart,
      background: Container(
        color: BloomColors.claySoft,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: BloomColors.clayDeep),
      ),
      onDismissed: (_) {
        final n = ref.read(weightProvider.notifier);
        n.remove(entry);
        final m = ScaffoldMessenger.of(context);
        m.hideCurrentSnackBar();
        m.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: BloomColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd)),
          content: Text('Removed ${units.weight(entry.kg)}', style: BloomText.body.copyWith(color: BloomColors.surface)),
          action: SnackBarAction(label: 'Undo', textColor: BloomColors.mustard, onPressed: () => n.log(entry.kg, entry.at)),
        ));
      },
      child: GroupRow(
        title: units.weight(entry.kg),
        caption: '${weekdays[t.weekday - 1]}, ${shortDate(t)} · $time',
        trailing: diff == null ? const BloomTag(text: 'First', tone: TagTone.neutral) : BloomTag(text: units.change(diff), tone: diff < -.04 ? TagTone.done : TagTone.neutral),
        last: last,
      ),
    );
  }
}
