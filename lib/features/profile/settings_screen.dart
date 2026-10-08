import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/reminders.dart';
import '../../data/premium.dart';
import '../../data/profile.dart';
import '../../ui/bits.dart';
import '../../ui/room_frame.dart';
import '../alarm/alarms_screen.dart';
import '../onboarding/onboarding_flow.dart' show pickTime;
import '../today/flow.dart';
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

    return SubPage(
      from: 'Profile',
      title: 'Settings',
      children: [
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
      ],
    );
  }
}
