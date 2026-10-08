import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/alarms.dart';
import '../../ui/bits.dart';
import '../../ui/clover_rive.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../onboarding/onboarding_flow.dart' show pickTime;

/// Wake-up alarms: when Clover wakes you next, and the list.
class AlarmsScreen extends ConsumerStatefulWidget {
  const AlarmsScreen({super.key});

  @override
  ConsumerState<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends ConsumerState<AlarmsScreen> {
  // The countdown moves on its own.
  late final Timer _tick = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _edit([AlarmItem? item]) async {
    final n = ref.read(alarmsProvider.notifier);
    if (item == null) await n.ensurePermissions();
    if (!mounted) return;
    await showBloomSheet<void>(context, (c) => AlarmSheet(item: item ?? AlarmItem(id: n.newId(), hour: 7, minute: 0), isNew: item == null));
  }

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmsProvider);
    final now = DateTime.now();
    final on = alarms.where((a) => a.enabled).toList();
    final next = on.isEmpty ? null : on.map((a) => (a, a.nextAfter(now))).reduce((x, y) => x.$2.isBefore(y.$2) ? x : y);
    String inText(Duration d) {
      final h = d.inHours, m = d.inMinutes % 60;
      return h == 0 ? 'in $m min' : 'in $h h $m min';
    }

    return SubPage(
      from: 'Profile',
      title: 'Wake-up alarms',
      bottom: LedgeButton(label: 'Add alarm', leading: const Icon(Icons.add_alarm_rounded, color: BloomColors.onForest), onPressed: () => _edit()),
      children: [
        BloomCard(
          child: Row(children: [
            SizedBox(width: 92, height: 108, child: LiveClover(action: next == null ? CloverAction.rest : CloverAction.reach)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Next wake-up'),
                Text(next == null ? 'None set' : next.$1.time, style: BloomText.displayXl.copyWith(fontSize: 40, fontFeatures: const [FontFeature.tabularFigures()])),
                Text(next == null ? 'Clover will gently wake you, then stretch with you.' : '${inText(next.$2.difference(now))} · ${next.$1.tune.title}', style: BloomText.caption.copyWith(fontSize: 14)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (alarms.isEmpty) Text('No alarms yet.', style: BloomText.bodyMuted, textAlign: TextAlign.center),
        for (final a in alarms) ...[
          Dismissible(
            key: ValueKey(a.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(color: BloomColors.claySoft, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
              child: const Icon(Icons.delete_outline_rounded, color: BloomColors.clayDeep),
            ),
            onDismissed: (_) {
              SfxPlayer.instance.play(Sfx.swipe);
              ref.read(alarmsProvider.notifier).remove(a);
              final m = ScaffoldMessenger.of(context);
              m.hideCurrentSnackBar();
              m.showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: BloomColors.ink,
                content: Text('Removed ${a.time}', style: BloomText.body.copyWith(color: BloomColors.surface)),
                action: SnackBarAction(label: 'Undo', textColor: BloomColors.mustard, onPressed: () => ref.read(alarmsProvider.notifier).save(a)),
              ));
            },
            child: GestureDetector(
              onTap: () => _edit(a),
              child: AnimatedOpacity(
                duration: BloomMotion.base,
                opacity: a.enabled ? 1 : .55,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  decoration: cardDecoration(radius: BloomSpace.rMd),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.time, style: BloomText.display.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                        Text([a.repeatLabel, if (a.label.isNotEmpty) a.label, a.tune.title].join(' · '), style: BloomText.caption),
                      ]),
                    ),
                    BloomToggle(label: 'Alarm ${a.time}', value: a.enabled, onChanged: (v) => ref.read(alarmsProvider.notifier).toggle(a, v)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Add or edit an alarm: time, days, label, tune (with a preview), and
/// how it rings.
class AlarmSheet extends ConsumerStatefulWidget {
  const AlarmSheet({super.key, required this.item, required this.isNew});
  final AlarmItem item;
  final bool isNew;

  @override
  ConsumerState<AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends ConsumerState<AlarmSheet> {
  late AlarmItem _a = widget.item;
  late final _label = TextEditingController(text: widget.item.label);
  // Made on first preview, so just opening the sheet never touches audio.
  AudioPlayer? _player;
  AlarmTune? _playing;

  @override
  void dispose() {
    _player?.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _preview(AlarmTune t) async {
    final player = _player ??= (AudioPlayer()..positionUpdater = null); // positions unused; the tracker ticks every frame
    if (_playing == t) {
      await player.stop();
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = t);
    try {
      await player.stop();
      await player.play(AssetSource(t.path.replaceFirst('assets/', '')), volume: .8);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(widget.isNew ? 'New alarm' : 'Edit alarm', style: BloomText.title),
      const SizedBox(height: 8),
      Center(
        child: GestureDetector(
          onTap: () => pickTime(context, _a.hour * 60 + _a.minute, (m) => setState(() => _a = _a.copyWith(hour: m ~/ 60, minute: m % 60))),
          child: Text(_a.time, style: BloomText.displayXl.copyWith(fontSize: 56, color: BloomColors.forest, decoration: TextDecoration.underline, decorationColor: BloomColors.sage)),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var d = 1; d <= 7; d++)
          GestureDetector(
            onTap: () {
              Feel.selectionClick();
              final days = {..._a.days};
              days.contains(d) ? days.remove(d) : days.add(d);
              setState(() => _a = _a.copyWith(days: days));
            },
            child: AnimatedContainer(
              duration: BloomMotion.fast,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _a.days.contains(d) ? BloomColors.forest : BloomColors.paperSunk),
              child: Text(names[d - 1], style: BloomText.button.copyWith(fontSize: 14, color: _a.days.contains(d) ? BloomColors.onForest : BloomColors.ink)),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Text(_a.repeatLabel, style: BloomText.caption, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextField(
        controller: _label,
        textCapitalization: TextCapitalization.sentences,
        style: BloomText.body,
        decoration: InputDecoration(
          hintText: 'Label (optional)',
          filled: true,
          fillColor: BloomColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.line, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.forest, width: 2)),
        ),
      ),
      const SizedBox(height: 12),
      const Eyebrow('Wake-up tune'),
      const SizedBox(height: 6),
      for (final t in AlarmTune.values)
        GestureDetector(
          onTap: () => setState(() => _a = _a.copyWith(tune: t)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: _a.tune == t ? BloomColors.forestSoft : BloomColors.surface,
              borderRadius: BorderRadius.circular(BloomSpace.rMd),
              border: Border.all(color: _a.tune == t ? BloomColors.forest : BloomColors.line, width: 2),
            ),
            child: Row(children: [
              Expanded(child: Text(t.title, style: BloomText.headline.copyWith(fontSize: 16, color: _a.tune == t ? BloomColors.forest : BloomColors.ink))),
              IconButton(
                tooltip: _playing == t ? 'Stop preview' : 'Play preview',
                onPressed: () => _preview(t),
                icon: Icon(_playing == t ? Icons.stop_circle_rounded : Icons.play_circle_rounded, color: BloomColors.forest, size: 30),
              ),
            ]),
          ),
        ),
      GroupCard(children: [
        GroupRow(title: 'Gentle start', caption: 'Fades in over 30 seconds', trailing: BloomToggle(label: 'Gentle start', value: _a.gentle, onChanged: (v) => setState(() => _a = _a.copyWith(gentle: v)))),
        GroupRow(title: 'Vibrate', trailing: BloomToggle(label: 'Vibrate', value: _a.vibrate, onChanged: (v) => setState(() => _a = _a.copyWith(vibrate: v))), last: true),
      ]),
      const SizedBox(height: 16),
      LedgeButton(
        label: 'Save alarm',
        onPressed: () {
          ref.read(alarmsProvider.notifier).save(_a.copyWith(label: _label.text.trim(), enabled: true));
          SfxPlayer.instance.play(Sfx.chime);
          Navigator.of(context).pop();
        },
      ),
      if (!widget.isNew)
        LedgeButton(
          label: 'Delete',
          variant: LedgeVariant.ghost,
          onPressed: () {
            ref.read(alarmsProvider.notifier).remove(_a);
            Navigator.of(context).pop();
          },
        ),
    ]);
  }
}
