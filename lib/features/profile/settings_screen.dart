import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/theme.dart';

import '../../app/reminders.dart';
import '../../data/borrowed.dart';
import '../../data/premium.dart';
import '../../data/today.dart';
import '../../data/profile.dart';
import '../../ui/bits.dart';
import '../../ui/room_frame.dart';
import '../alarm/alarms_screen.dart';
import '../lab/move_lab_screen.dart';
import '../onboarding/onboarding_flow.dart' show pickTime;
import '../today/flow.dart';
import 'subscription_screen.dart';
import 'widget_sheet.dart';

/// Settings, off the Profile's gear: reminders, sound and feel, units, account.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final update = ref.read(profileProvider.notifier).update;
    Future<void> reminder(bool morning, bool on) async {
      if (on && !await Reminders.requestPermission()) return;
      final p = ref.read(profileProvider);
      update(morning ? p.copyWith(morning: on) : p.copyWith(evening: on));
    }

    final premium = ref.watch(premiumProvider);
    final borrowed = ref.watch(borrowedProvider);
    final paws = ref.watch(todayProvider.select((s) => s.paws));
    return SubPage(
      from: 'Profile',
      title: 'Settings',
      children: [
        const Eyebrow('Membership'),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(
            title: 'Subscription',
            caption: premium.active
                ? 'Bloom Plus · ${premium.plan?.label ?? 'Plus'}${premium.test ? ' · test' : ''}'
                : 'Free plan · see what Plus adds',
            onTap: () => Navigator.of(context).push(bloomRoute(const SubscriptionScreen())),
            last: true,
          ),
        ]),
        const SizedBox(height: 20),
        const Eyebrow('Reminders'),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(
            title: 'Morning reminder',
            caption: profile.morning ? '${clockText(profile.morningAt)} · tap to change' : 'A look at today’s plan',
            onTap: profile.morning ? () => pickTime(context, profile.morningAt, (m) => update(ref.read(profileProvider).copyWith(morningAt: m))) : null,
            trailing: BloomToggle(label: 'Morning reminder', value: profile.morning, onChanged: (v) => reminder(true, v)),
          ),
          GroupRow(
            title: 'Evening reminder',
            caption: profile.evening ? '${clockText(profile.eveningAt)} · tap to change' : 'How did today go?',
            onTap: profile.evening ? () => pickTime(context, profile.eveningAt, (m) => update(ref.read(profileProvider).copyWith(eveningAt: m))) : null,
            trailing: BloomToggle(label: 'Evening reminder', value: profile.evening, onChanged: (v) => reminder(false, v)),
          ),
          GroupRow(
            title: 'Wake-up alarms',
            caption: 'Clover wakes you, then stretches with you',
            onTap: () => Navigator.of(context).push(bloomRoute(const AlarmsScreen())),
            last: true,
          ),
        ]),
        const SizedBox(height: 20),
        const Eyebrow('Sound & feel'),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(
            title: 'Sounds',
            caption: 'Pops, ticks and cheers',
            trailing: BloomToggle(label: 'Sounds', value: profile.sound, onChanged: (v) => update(profile.copyWith(sound: v))),
          ),
          GroupRow(
            title: 'Haptics',
            caption: 'Little taps on wins',
            trailing: BloomToggle(label: 'Haptics', value: profile.haptics, onChanged: (v) => update(profile.copyWith(haptics: v))),
            last: true,
          ),
        ]),
        const SizedBox(height: 20),
        const Eyebrow('General'),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(
            title: 'Units',
            caption: profile.pounds ? 'Pounds' : 'Kilograms',
            trailing: SizedBox(
              width: 120,
              child: SegmentedSwitch(labels: const ['kg', 'lb'], index: profile.pounds ? 1 : 0, onChanged: (i) => update(profile.copyWith(pounds: i == 1))),
            ),
          ),
          GroupRow(
            title: 'Home-screen widgets',
            caption: 'Clover and today’s moves at a glance',
            onTap: () => showBloomSheet<void>(context, (c) => const WidgetSheet()),
          ),
          // Test builds only (LAB=true): every move, in preview. Compiled out of normal builds.
          if (MoveLabScreen.enabled)
            GroupRow(
              title: 'Move lab',
              caption: 'Test build · try every move, nothing is saved',
              onTap: () => Navigator.of(context).push(bloomRoute(const MoveLabScreen())),
            ),
          GroupRow(title: 'Account', caption: 'Guest · everything stays on this phone'),
          GroupRow(
            title: 'Start over from onboarding',
            caption: 'Replays the welcome; your moves and logs stay',
            onTap: () {
              ref.read(premiumProvider.notifier).reset();
              update(ref.read(profileProvider).copyWith(onboarded: false));
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            last: true,
          ),
        ]),
        const SizedBox(height: 20),
        // For testing the Shop: paws on loan, as many as you like, handed back in one go.
        const Eyebrow('Testing'),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(
            title: 'Borrow paws',
            caption: borrowed == 0 ? 'Test paws for the Shop · $paws in the balance' : '$borrowed borrowed · $paws in the balance',
            trailing: _SmallButton(label: '+1,000', onTap: () => ref.read(borrowedProvider.notifier).borrow(1000)),
          ),
          GroupRow(
            title: 'Give borrowed paws back',
            caption: borrowed == 0 ? 'Nothing borrowed' : 'Takes back up to $borrowed (spent ones are forgiven)',
            onTap: borrowed == 0 ? null : () => ref.read(borrowedProvider.notifier).giveBack(),
            last: true,
          ),
        ]),
      ],
    );
  }
}

/// A compact pill button for a settings row.
class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Borrow 1,000 paws',
        child: GestureDetector(
          onTap: () {
            Feel.selectionClick();
            onTap();
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: BloomColors.skyDeep, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
            child: Text(label, style: BloomText.button.copyWith(fontSize: 14, color: BloomColors.surface)),
          ),
        ),
      );
}
