import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/plan.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import 'rule_sheet.dart';

/// The balcony garden: small daily rules to do more of, and things to skip.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final total = plan.rules.length;
    final kept = plan.keptCount;
    final line = total == 0
        ? 'Let’s plant our first habit!'
        : kept == total
            ? 'Every one kept. We’re blooming!'
            : kept == 0
                ? 'Watering our good habits!'
                : '$kept down, ${total - kept} to go!';
    return RoomFrame(
      asset: 'assets/scenes/balcony.jpg',
      line: line,
      title: 'Plan',
      subtitle: AnimatedSwitcher(
        duration: BloomMotion.base,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
        child: Text('$kept of $total kept today · +${kept * kPawsPerRule} paws', key: ValueKey(kept), style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      ),
      children: [
        _KeptBar(value: total == 0 ? 0 : kept / total),
        const SizedBox(height: 18),
        _Section(kind: PlanKind.more, plan: plan),
        const SizedBox(height: 18),
        _Section(kind: PlanKind.skip, plan: plan),
        const SizedBox(height: 18),
        LedgeButton(
          label: 'Add a rule',
          variant: LedgeVariant.secondary,
          leading: const Icon(Icons.add_rounded, color: BloomColors.ink),
          onPressed: (ref.read(planProvider.notifier).canAdd(PlanKind.more) || ref.read(planProvider.notifier).canAdd(PlanKind.skip))
              ? () => showBloomSheet<void>(context, (c) => const RuleSheet())
              : null,
        ),
      ],
    );
  }
}

class _KeptBar extends StatelessWidget {
  const _KeptBar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(BloomSpace.rPill),
        child: SizedBox(
          height: 12,
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: BloomColors.paperSunk)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: const Duration(milliseconds: 520),
              curve: BloomMotion.spring,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                child: Container(decoration: BoxDecoration(color: BloomColors.forest, borderRadius: BorderRadius.circular(BloomSpace.rPill))),
              ),
            ),
          ]),
        ),
      );
}

class _Section extends ConsumerWidget {
  const _Section({required this.kind, required this.plan});
  final PlanKind kind;
  final Plan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = plan.of(kind);
    final more = kind == PlanKind.more;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: more ? BloomColors.forestSoft : BloomColors.claySoft, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
          child: Text(more ? 'DO MORE OF' : 'SKIP', style: BloomText.label.copyWith(color: more ? BloomColors.forest : BloomColors.clayDeep, letterSpacing: .6)),
        ),
        const Spacer(),
        Text('${rules.length} of $kMaxRules', style: BloomText.caption),
      ]),
      const SizedBox(height: 12),
      if (rules.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
          child: Text(more ? 'Nothing here yet. Add something small you’d like to do more of.' : 'Nothing to skip yet. Add one thing you’d like to cut back on.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
        ),
      for (final r in rules) ...[
        _RuleRow(key: ValueKey(r.id), rule: r, kept: plan.isKept(r.id)),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

class _RuleRow extends ConsumerStatefulWidget {
  const _RuleRow({super.key, required this.rule, required this.kept});
  final PlanRule rule;
  final bool kept;

  @override
  ConsumerState<_RuleRow> createState() => _RuleRowState();
}

class _RuleRowState extends ConsumerState<_RuleRow> {
  final _checkKey = GlobalKey();

  void _toggle() {
    final on = ref.read(planProvider.notifier).toggle(widget.rule.id);
    if (on) {
      HapticFeedback.lightImpact();
      final box = _checkKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final c = box.localToGlobal(box.size.center(Offset.zero));
        FxLayer.fly(c, c + const Offset(-30, -150), '+$kPawsPerRule');
        FxLayer.burst(c, count: 14, power: .45);
      }
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _remove() {
    final notifier = ref.read(planProvider.notifier);
    final rule = widget.rule;
    final index = notifier.remove(rule.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      backgroundColor: BloomColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd)),
      content: Text('Removed “${rule.title}”', style: BloomText.body.copyWith(color: BloomColors.surface)),
      action: SnackBarAction(label: 'Undo', textColor: BloomColors.mustard, onPressed: () => notifier.restore(rule, index)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rule;
    final more = r.kind == PlanKind.more;
    final kept = widget.kept;
    return Dismissible(
      key: ValueKey('dismiss-${r.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: BloomColors.claySoft, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Remove', style: BloomText.button.copyWith(color: BloomColors.clayDeep, fontSize: 15)),
          const SizedBox(width: 6),
          const Icon(Icons.delete_outline_rounded, color: BloomColors.clayDeep),
        ]),
      ),
      child: GestureDetector(
        onTap: () => showBloomSheet<void>(context, (c) => RuleSheet(editing: r)),
        child: AnimatedContainer(
          duration: BloomMotion.base,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: BloomColors.surface,
            borderRadius: BorderRadius.circular(BloomSpace.rMd),
            boxShadow: const [BoxShadow(color: BloomColors.line, offset: Offset(0, 1)), BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: more ? BloomColors.forestSoft : BloomColors.claySoft, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
              child: Icon(iconFor(r.icon), color: more ? BloomColors.forest : BloomColors.clayDeep, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedDefaultTextStyle(
                  duration: BloomMotion.base,
                  style: BloomText.headline.copyWith(
                    fontSize: 16,
                    height: 22 / 16,
                    color: kept && more ? BloomColors.inkMuted : BloomColors.ink,
                    decoration: kept && more ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationThickness: 2,
                  ),
                  child: Text(r.title),
                ),
                Text(
                  kept ? (more ? 'Done · +$kPawsPerRule paws' : 'Skipped it today · +$kPawsPerRule paws') : (more ? 'Daily' : 'Today'),
                  style: BloomText.caption,
                ),
              ]),
            ),
            _Check(key: _checkKey, on: kept, skip: !more, onTap: _toggle, label: r.title),
          ]),
        ),
      ),
    );
  }
}

/// The tick box: pops when ticked, on a little ledge.
class _Check extends StatelessWidget {
  const _Check({super.key, required this.on, required this.skip, required this.onTap, required this.label});
  final bool on, skip;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fill = on ? (skip ? BloomColors.claySoft : BloomColors.forest) : BloomColors.surface;
    final fg = on ? (skip ? BloomColors.clayDeep : BloomColors.onForest) : BloomColors.lineStrong;
    return Semantics(
      checked: on,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(on),
          tween: Tween(begin: on ? .7 : 1, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: BloomMotion.pop,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: AnimatedContainer(
            duration: BloomMotion.fast,
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? (skip ? BloomColors.clayDeep : BloomColors.forest) : BloomColors.lineStrong, width: 2),
              boxShadow: [BoxShadow(color: on && !skip ? BloomColors.forestPress : BloomColors.line, offset: const Offset(0, 3))],
            ),
            child: Icon(skip ? Icons.close_rounded : Icons.check_rounded, color: fg, size: 22, weight: 700),
          ),
        ),
      ),
    );
  }
}
