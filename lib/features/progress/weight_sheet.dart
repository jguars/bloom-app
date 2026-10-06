import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/profile.dart';
import '../../data/weight.dart';
import '../../ui/bits.dart';
import '../../ui/ledge_button.dart';
import '../../ui/weight_chart.dart';

/// Log today's weight (and, the first time, set a goal), or edit the goal.
/// Pops with true when something was saved.
class WeightSheet extends ConsumerStatefulWidget {
  const WeightSheet({super.key, this.goalOnly = false});
  final bool goalOnly;

  @override
  ConsumerState<WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends ConsumerState<WeightSheet> {
  late final WeightLog _log = ref.read(weightProvider);
  late double _kg = _log.latest?.kg ?? 75;
  late double _goal = _log.goalKg ?? ((_log.latest?.kg ?? 75) - 5);

  bool get _firstTime => _log.entries.isEmpty && !widget.goalOnly;

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    final last = _log.latest;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(widget.goalOnly ? 'Your goal weight' : 'Log today’s weight', style: BloomText.title),
      const SizedBox(height: 2),
      Text(
        widget.goalOnly
            ? 'Clover will pace it gently, about ${units.weight(kPlannedKgPerWeek)} a week.'
            : last == null
                ? 'Only you see this. It sets a safe pace for you both.'
                : 'Last: ${units.weight(last.kg)} ${_when(last.at)}',
        style: BloomText.bodyMuted.copyWith(fontSize: 15),
      ),
      const SizedBox(height: 18),
      if (!widget.goalOnly) ...[
        if (_firstTime) const Padding(padding: EdgeInsets.only(bottom: 8), child: Eyebrow('Today')),
        WeightStepper(kg: _kg, units: units, label: 'Today’s weight', onChanged: (v) => setState(() => _kg = v)),
        const SizedBox(height: 12),
        if (last != null)
          Align(
            alignment: Alignment.centerLeft,
            child: BloomTag(
              text: '${units.change(_kg - last.kg)} since ${_dayName(last.at) == 'today' ? 'earlier' : _dayName(last.at)}',
              tone: _kg <= last.kg ? TagTone.done : TagTone.neutral,
            ),
          ),
      ],
      if (_firstTime || widget.goalOnly) ...[
        if (_firstTime) const Padding(padding: EdgeInsets.only(top: 10, bottom: 8), child: Eyebrow('Goal')),
        WeightStepper(kg: _goal, units: units, label: 'Goal weight', onChanged: (v) => setState(() => _goal = v)),
        const SizedBox(height: 10),
        Text(_goalNote(units), style: BloomText.caption.copyWith(fontSize: 14)),
      ],
      const SizedBox(height: 20),
      LedgeButton(
        label: widget.goalOnly ? 'Save goal' : 'Save weight',
        onPressed: () {
          final n = ref.read(weightProvider.notifier);
          if (!widget.goalOnly) n.log(_kg);
          if (_firstTime || widget.goalOnly) n.setGoal(_goal);
          Navigator.of(context).pop(true);
        },
      ),
    ]);
  }

  String _goalNote(Units u) {
    final from = widget.goalOnly ? (_log.first?.kg ?? _kg) : _kg;
    final diff = from - _goal;
    if (diff <= .05) return 'Pick a goal a little below where you are.';
    final weeks = (diff / kPlannedKgPerWeek).ceil();
    return 'That’s ${u.weight(diff)} to go, about $weeks weeks at a gentle pace.';
  }

  String _when(DateTime t) {
    final d = _dayName(t);
    return d == 'today' || d == 'yesterday' ? d : 'on $d';
  }

  String _dayName(DateTime t) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return weekdays[t.weekday - 1];
    return shortDate(t);
  }
}

/// − big number + . Hold a button to run; drag across the number to scrub.
class WeightStepper extends StatefulWidget {
  const WeightStepper({super.key, required this.kg, required this.units, required this.onChanged, required this.label});
  final double kg;
  final Units units;
  final ValueChanged<double> onChanged;
  final String label;

  @override
  State<WeightStepper> createState() => _WeightStepperState();
}

class _WeightStepperState extends State<WeightStepper> {
  Timer? _hold;
  int _dir = 1;
  double _drag = 0;

  void _step(int dir) {
    _dir = dir;
    final next = (widget.kg + dir * widget.units.stepKg).clamp(30.0, 300.0);
    Feel.selectionClick();
    widget.onChanged(next);
  }

  void _startHold(int dir) {
    _hold?.cancel();
    var n = 0;
    _hold = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (++n > 5) _step(dir); // a short pause before it runs
    });
  }

  void _endHold() => _hold?.cancel();

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.units;
    Widget btn(int dir) => Semantics(
          button: true,
          label: '${dir < 0 ? 'Decrease' : 'Increase'} ${widget.label.toLowerCase()}',
          child: GestureDetector(
            onTap: () => _step(dir),
            onLongPressStart: (_) => _startHold(dir),
            onLongPressEnd: (_) => _endHold(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: BloomColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: BloomColors.line, width: 2),
                boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 3))],
              ),
              child: Icon(dir < 0 ? Icons.remove_rounded : Icons.add_rounded, color: BloomColors.ink, size: 28),
            ),
          ),
        );
    return Row(children: [
      btn(-1),
      Expanded(
        child: GestureDetector(
          onHorizontalDragUpdate: (d) {
            _drag += d.delta.dx;
            while (_drag.abs() >= 10) {
              _step(_drag > 0 ? 1 : -1);
              _drag -= _drag.sign * 10;
            }
          },
          child: Semantics(
            label: '${widget.label}: ${u.weight(widget.kg)}',
            child: Container(
              height: 72,
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (c, a) {
                      final incoming = c.key == ValueKey(u.value(widget.kg));
                      final from = Offset(0, (incoming ? .5 : -.5) * _dir);
                      return SlideTransition(
                        position: Tween(begin: from, end: Offset.zero).animate(CurvedAnimation(parent: a, curve: BloomMotion.enter)),
                        child: FadeTransition(opacity: a, child: c),
                      );
                    },
                    child: Text(
                      u.value(widget.kg),
                      key: ValueKey(u.value(widget.kg)),
                      style: BloomText.displayXl.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(u.name, style: BloomText.title.copyWith(color: BloomColors.inkMuted)),
              ]),
            ),
          ),
        ),
      ),
      btn(1),
    ]);
  }
}
