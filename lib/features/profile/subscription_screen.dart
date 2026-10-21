import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/theme.dart';
import '../../data/premium.dart';
import '../../ui/bits.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../../ui/weight_chart.dart' show shortDate;
import '../paywall/paywall_screen.dart';
import '../today/flow.dart';

/// Settings › Subscription: which plan she's on. On Bloom Plus: the plan, the trial, and cancelling. On the free plan:
/// what Plus adds, and the way to it. No store is connected yet, so plans here are test purchases.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  static void openPaywall(BuildContext context) =>
      Navigator.of(context).push(bloomRoute(Builder(builder: (c) => Scaffold(body: PaywallScreen(onDone: () => Navigator.of(c).pop())))));

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final yes = await showBloomSheet<bool>(context, (c) => const _CancelSheet());
    if (yes != true) return;
    await ref.read(premiumProvider.notifier).cancel();
    Feel.mediumImpact();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(premiumProvider);
    return SubPage(
      from: 'Settings',
      title: 'Subscription',
      children: [
        const Eyebrow('Your plan'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: p.active ? BloomColors.mustardSoft : BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rLg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(p.active ? Icons.auto_awesome_rounded : Icons.spa_outlined, color: p.active ? BloomColors.ink : BloomColors.forest),
              const SizedBox(width: 10),
              Expanded(child: Text(p.active ? 'Bloom Plus' : 'Free plan', style: BloomText.title)),
              if (p.test)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: BloomColors.surface, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                  child: Text('Test', style: BloomText.label.copyWith(color: BloomColors.inkMuted)),
                ),
            ]),
            const SizedBox(height: 8),
            Text(
              p.active
                  ? [
                      '${p.plan?.label ?? 'Plus'} · ${p.plan?.priceText ?? ''}${p.plan == PremiumPlan.monthly ? ' a month' : ' a year'}',
                      if (p.trialEnds != null) 'Free until ${shortDate(p.trialEnds!)}',
                    ].join('\n')
                  : 'Moves without gear, the daily plan, cravings help and Clover’s everyday outfits.',
              style: BloomText.bodyMuted.copyWith(height: 1.45),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        if (p.active) ...[
          LedgeButton(label: 'Cancel subscription', variant: LedgeVariant.secondary, onPressed: () => _cancel(context, ref)),
          const SizedBox(height: 10),
          Text(
            p.test ? 'Test purchase: cancelling ends Plus right away, so you can try the free plan.' : 'You keep Plus until the end of the period you’ve paid for.',
            style: BloomText.caption,
            textAlign: TextAlign.center,
          ),
        ] else ...[
          LedgeButton(label: 'See Bloom Plus', glow: true, onPressed: () => openPaywall(context)),
          const SizedBox(height: 10),
          Text('Test mode: no store is connected yet, so nothing is charged.', style: BloomText.caption, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _CancelSheet extends StatelessWidget {
  const _CancelSheet();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Cancel Bloom Plus?', style: BloomText.title),
          const SizedBox(height: 6),
          Text('Plus moves, outfits and reports lock again. Everything you’ve done together stays.', style: BloomText.bodyMuted.copyWith(height: 1.4)),
          const SizedBox(height: 18),
          LedgeButton(label: 'Cancel subscription', onPressed: () => Navigator.of(context).pop(true)),
          const SizedBox(height: 8),
          LedgeButton(label: 'Keep Plus', variant: LedgeVariant.ghost, onPressed: () => Navigator.of(context).pop(false)),
        ],
      );
}
