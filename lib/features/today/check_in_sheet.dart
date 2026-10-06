import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/plan.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';

/// What the sheet hands back: the answer, whether it's the first check-in
/// today (paws are due), and where the button was, for the paws to fly from.
typedef CheckInResult = ({CheckIn answer, bool first, Offset from});

/// "How did today go?": three faces, today's plan (tap a rule you kept but
/// forgot to tick), and save.
class CheckInSheet extends ConsumerStatefulWidget {
  const CheckInSheet({super.key});

  @override
  ConsumerState<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<CheckInSheet> {
  late CheckIn? _answer = ref.read(journalProvider).todayLog.checkIn ?? _suggest();
  final _saveKey = GlobalKey();

  /// A gentle starting guess from the plan; never pre-picks "Not today".
  CheckIn? _suggest() {
    final plan = ref.read(planProvider);
    if (plan.rules.isEmpty) return null;
    final share = plan.keptCount / plan.rules.length;
    return share >= 1 ? CheckIn.all : (share >= .5 ? CheckIn.mostly : null);
  }

  void _save() {
    final a = _answer;
    if (a == null) return;
    final first = ref.read(journalProvider.notifier).logCheckIn(a);
    final box = _saveKey.currentContext?.findRenderObject() as RenderBox?;
    final from = box == null ? Offset.zero : box.localToGlobal(box.size.center(Offset.zero));
    Navigator.of(context).pop<CheckInResult>((answer: a, first: first, from: from));
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final again = ref.watch(journalProvider.select((j) => j.todayLog.checkIn != null));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('How did today go?', style: BloomText.title),
      const SizedBox(height: 2),
      Text('Clover’s curious. Tap the closest one.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      const SizedBox(height: 16),
      Row(children: [
        for (final c in CheckIn.values) ...[
          if (c != CheckIn.all) const SizedBox(width: 12),
          Expanded(
            child: _Option(
              answer: c,
              selected: _answer == c,
              onTap: () => setState(() => _answer = c),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Text('YOUR PLAN TODAY', style: BloomText.label),
        const Spacer(),
        Text('${plan.keptCount} of ${plan.rules.length} kept', style: BloomText.caption),
      ]),
      const SizedBox(height: 8),
      if (plan.rules.isEmpty)
        Text('No rules yet. Add a few on the balcony.', style: BloomText.bodyMuted.copyWith(fontSize: 15))
      else ...[
        Wrap(spacing: 8, runSpacing: 8, children: [for (final r in plan.rules) _RuleChip(rule: r, kept: plan.isKept(r.id))]),
        const SizedBox(height: 6),
        Text('Kept one but forgot to tick it? Tap it here.', style: BloomText.caption),
      ],
      const SizedBox(height: 20),
      KeyedSubtree(
        key: _saveKey,
        child: LedgeButton(label: again ? 'Update check-in' : 'Save check-in', onPressed: _answer == null ? null : _save),
      ),
    ]);
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.answer, required this.selected, required this.onTap});
  final CheckIn answer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: answer.label,
        child: GestureDetector(
          onTap: () {
            Feel.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: BloomMotion.base,
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
            decoration: BoxDecoration(
              color: selected ? BloomColors.forestSoft : BloomColors.surface,
              borderRadius: BorderRadius.circular(BloomSpace.rMd),
              border: Border.all(color: selected ? BloomColors.forest : BloomColors.line, width: 2),
              boxShadow: [BoxShadow(color: selected ? BloomColors.forestPress : BloomColors.line, offset: const Offset(0, 3))],
            ),
            child: Column(children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(selected),
                tween: Tween(begin: selected ? 0 : 1, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.linear,
                builder: (context, t, _) {
                  // Selected: pop up and give a little nod.
                  final s = selected ? 1 + .25 * math.sin(t * math.pi) : 1.0;
                  final turn = selected ? .06 * math.sin(t * math.pi * 2) : 0.0;
                  return Transform.rotate(
                    angle: turn,
                    child: Transform.scale(scale: s, child: CustomPaint(size: const Size(34, 34), painter: _FacePainter(answer, selected ? BloomColors.forest : BloomColors.ink))),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(answer.label, style: BloomText.button.copyWith(fontSize: 14, color: selected ? BloomColors.forest : BloomColors.ink), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

/// Round line faces from the design: smile, flat, gentle down-turn.
class _FacePainter extends CustomPainter {
  _FacePainter(this.answer, this.color);
  final CheckIn answer;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(12, 12), 9, p);
    final dot = Paint()..color = color;
    canvas.drawCircle(const Offset(9, 10), 1.3, dot);
    canvas.drawCircle(const Offset(15, 10), 1.3, dot);
    p.strokeWidth = 2.4;
    final mouth = switch (answer) {
      CheckIn.all => Path()
        ..moveTo(8, 14.5)
        ..quadraticBezierTo(12, 18.4, 16, 14.5),
      CheckIn.mostly => Path()
        ..moveTo(8.5, 15.5)
        ..lineTo(15.5, 15.5),
      CheckIn.not => Path()
        ..moveTo(8.5, 16)
        ..quadraticBezierTo(12, 13.4, 15.5, 16),
    };
    canvas.drawPath(mouth, p);
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.answer != answer || old.color != color;
}

/// A rule as a chip: kept ones in their status colours, the rest tappable.
class _RuleChip extends ConsumerWidget {
  const _RuleChip({required this.rule, required this.kept});
  final PlanRule rule;
  final bool kept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final more = rule.kind == PlanKind.more;
    final (bg, fg) = !kept ? (BloomColors.paperSunk, BloomColors.inkMuted) : (more ? (BloomColors.forestSoft, BloomColors.forest) : (BloomColors.claySoft, BloomColors.clayDeep));
    final text = more ? rule.title : (kept ? 'Skipped ${rule.title.toLowerCase()}' : 'Skip ${rule.title.toLowerCase()}');
    return Semantics(
      button: true,
      checked: kept,
      label: rule.title,
      child: GestureDetector(
        onTap: () {
          final on = ref.read(planProvider.notifier).toggle(rule.id);
          final box = context.findRenderObject() as RenderBox?;
          if (on && box != null) {
            Feel.lightImpact();
            final c = box.localToGlobal(box.size.center(Offset.zero));
            FxLayer.fly(c, c + const Offset(0, -90), '+$kPawsPerRule');
          } else {
            Feel.selectionClick();
          }
        },
        child: TweenAnimationBuilder<double>(
          key: ValueKey(kept),
          tween: Tween(begin: kept ? .8 : 1, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: BloomMotion.pop,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: AnimatedContainer(
            duration: BloomMotion.base,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BloomSpace.rPill), border: Border.all(color: kept ? Colors.transparent : BloomColors.line, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(kept ? (more ? Icons.check_rounded : Icons.close_rounded) : Icons.add_rounded, size: 16, color: fg),
              const SizedBox(width: 5),
              Text(text, style: BloomText.button.copyWith(fontSize: 14, color: kept ? fg : BloomColors.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}
