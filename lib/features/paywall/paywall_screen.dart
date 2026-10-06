import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/premium.dart';
import '../../ui/fx_layer.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/scene.dart';
import '../../ui/weight_chart.dart';

/// Bloom Plus. Used as the last onboarding step and from Profile. There is
/// no store yet, so starting a plan is a clearly labelled test purchase.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  var _plan = PremiumPlan.yearly;
  bool _joined = false;
  final _ctaKey = GlobalKey();

  Future<void> _buy() async {
    await ref.read(premiumProvider.notifier).startTest(_plan);
    if (!mounted) return;
    SfxPlayer.instance.play(Sfx.cheer);
    Feel.heavyImpact();
    final box = _ctaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final c = box.localToGlobal(box.size.center(Offset.zero));
      FxLayer.burst(c, count: 40, power: 1);
      Future.delayed(const Duration(milliseconds: 250), () => FxLayer.burst(c + const Offset(0, -260), count: 30, power: .9));
    }
    setState(() => _joined = true);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sceneH = 360.0 + mq.padding.top * .4;
    final ends = DateTime.now().add(const Duration(days: kTrialDays));
    return ColoredBox(
      color: BloomColors.surface,
      child: Stack(fit: StackFit.expand, children: [
        Positioned(left: 0, right: 0, top: 0, child: Scene(asset: 'assets/scenes/gift.jpg', height: sceneH, fadeHeight: 80, alignment: const Alignment(0, .4), motion: SceneMotion.beat)),
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, sceneH - 24, 20, 24 + mq.padding.bottom),
          children: [
            AnimatedSwitcher(
              duration: BloomMotion.slow,
              switchInCurve: BloomMotion.pop,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(a), child: c)),
              child: _joined ? _welcome() : _offer(ends),
            ),
          ],
        ),
        if (!_joined)
          Positioned(
            right: 12,
            top: mq.padding.top + 8,
            child: Semantics(
              button: true,
              label: 'Close',
              child: GestureDetector(
                onTap: widget.onDone,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1F2E3826), blurRadius: 12, offset: Offset(0, 4))]),
                  child: const Icon(Icons.close_rounded, color: BloomColors.ink),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _offer(DateTime ends) {
    final yearly = _plan == PremiumPlan.yearly;
    return Column(key: const ValueKey('offer'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RiseIn(child: Text('Grow together with Bloom Plus', style: BloomText.display, textAlign: TextAlign.center)),
      const SizedBox(height: 14),
      for (final (i, p) in const ['All 40 moves, with every piece of gear', 'Weekly summary and plan report', 'New outfits and room decor for Clover'].indexed)
        RiseIn(
          delay: Duration(milliseconds: 120 + 70 * i),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: BloomColors.forest, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(p, style: BloomText.body)),
            ]),
          ),
        ),
      const SizedBox(height: 10),
      RiseIn(delay: const Duration(milliseconds: 360), child: _PlanOption(plan: PremiumPlan.yearly, selected: yearly, sub: '\$3.33 a month, billed yearly', badge: '$kTrialDays days free', onTap: () => setState(() => _plan = PremiumPlan.yearly))),
      const SizedBox(height: 10),
      RiseIn(delay: const Duration(milliseconds: 420), child: _PlanOption(plan: PremiumPlan.monthly, selected: !yearly, sub: 'Cancel anytime', onTap: () => setState(() => _plan = PremiumPlan.monthly))),
      const SizedBox(height: 14),
      Text(
        yearly
            ? 'Free for $kTrialDays days, then ${PremiumPlan.yearly.priceText} a year. Cancel anytime in Settings before ${shortDate(ends)} and you won’t be charged.'
            : '${PremiumPlan.monthly.priceText} a month. Cancel anytime in Settings.',
        style: BloomText.caption,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      KeyedSubtree(key: _ctaKey, child: LedgeButton(label: yearly ? 'Start my free week' : 'Start monthly', glow: true, onPressed: _buy)),
      const SizedBox(height: 4),
      LedgeButton(label: 'Not now', variant: LedgeVariant.ghost, onPressed: widget.onDone),
      Text('Test mode: no store is connected yet, so nothing is charged.', style: BloomText.caption.copyWith(fontSize: 12), textAlign: TextAlign.center),
    ]);
  }

  Widget _welcome() => Column(key: const ValueKey('joined'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PopIn(child: Text('Welcome to Bloom Plus!', style: BloomText.display, textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        RiseIn(
          delay: const Duration(milliseconds: 120),
          child: Text('Clover’s already planning outfits. Let’s go and move together.', style: BloomText.bodyMuted, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 24),
        RiseIn(delay: const Duration(milliseconds: 220), child: LedgeButton(label: 'Let’s go', onPressed: widget.onDone)),
      ]);
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({required this.plan, required this.selected, required this.sub, required this.onTap, this.badge});
  final PremiumPlan plan;
  final bool selected;
  final String sub;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: '${plan.label}, ${plan.priceText}',
        child: GestureDetector(
          onTap: () {
            Feel.selectionClick();
            onTap();
          },
          child: Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: BloomMotion.base,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: selected ? BloomColors.forestSoft : BloomColors.surface,
                borderRadius: BorderRadius.circular(BloomSpace.rMd),
                border: Border.all(color: selected ? BloomColors.forest : BloomColors.line, width: 2),
                boxShadow: [BoxShadow(color: selected ? BloomColors.sage : BloomColors.line, offset: const Offset(0, 3))],
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: BloomMotion.fast,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: BloomColors.surface, border: Border.all(color: selected ? BloomColors.forest : BloomColors.lineStrong, width: selected ? 7 : 2)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan.label, style: BloomText.headline),
                    Text(sub, style: BloomText.caption),
                  ]),
                ),
                Text(plan.priceText, style: BloomText.number.copyWith(fontSize: 18)),
              ]),
            ),
            if (badge != null)
              Positioned(
                right: 14,
                top: -11,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: BloomColors.mustard, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                  child: Text(badge!, style: BloomText.caption.copyWith(color: BloomColors.ink, fontWeight: FontWeight.w800, fontVariations: const [FontVariation('wght', 800)])),
                ),
              ),
          ]),
        ),
      );
}
