import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/journal.dart';
import '../../data/plan.dart';
import '../../data/profile.dart';
import '../../data/weight.dart';
import '../../ui/bits.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/room_frame.dart';
import '../../ui/weight_chart.dart';
import '../today/flow.dart';
import 'plan_report_screen.dart';
import 'week_stats.dart';
import 'weekly_screen.dart';
import 'weight_history_screen.dart';

/// The bedroom: you and Clover, this week, reports and settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final journal = ref.watch(journalProvider);
    final log = ref.watch(weightProvider);
    final plan = ref.watch(planProvider);
    final units = ref.watch(unitsProvider);
    final week = WeekStats(journal);
    final days = journal.dayNumber;
    final kept = week.planKept;
    final best = week.bestRule(plan.rules);
    final hour = DateTime.now().hour;
    final line = hour >= 20 || hour < 5 ? 'Story time, then sleep.' : (hour < 11 ? 'Five more minutes…' : 'My comfy corner!');
    final update = ref.read(profileProvider.notifier).update;

    return RoomFrame(
      asset: 'assets/scenes/bedroom.jpg',
      line: line,
      title: '${profile.displayName} & ${profile.catName}',
      subtitle: Row(children: [
        Expanded(child: Text(days == 0 ? 'Together since today' : 'Together for ${days + 1} days', style: BloomText.bodyMuted.copyWith(fontSize: 15))),
        GestureDetector(
          onTap: () => showBloomSheet<void>(context, (c) => const _NamesSheet()),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('Edit names', style: BloomText.button.copyWith(fontSize: 15, color: BloomColors.forest))),
        ),
      ]),
      children: [
        const Eyebrow('This week'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: StatCard(value: '${week.moves}', label: 'Moves')),
          const SizedBox(width: 10),
          Expanded(child: StatCard(value: kept == null ? '—' : '${(kept * 100).round()}%', label: 'Plan kept')),
          const SizedBox(width: 10),
          Expanded(child: StatCard(value: '${week.activeDays} of 7', label: 'Active days')),
        ]),
        const SizedBox(height: 20),
        const Eyebrow('Reports'),
        const SizedBox(height: 10),
        GroupCard(children: [
          GroupRow(
            leading: const _RowIcon(Icons.calendar_view_week_rounded),
            title: 'Weekly summary',
            caption: '${shortDate(week.days.first)} – ${shortDate(week.days.last)}',
            onTap: () => Navigator.of(context).push(bloomRoute(const WeeklyScreen())),
          ),
          GroupRow(
            leading: const _RowIcon(Icons.monitor_weight_outlined),
            title: 'Weight history',
            caption: log.entries.isEmpty ? 'No weigh-ins yet' : '${log.entries.length} ${log.entries.length == 1 ? 'log' : 'logs'} · latest ${units.weight(log.latest!.kg)}',
            onTap: () => Navigator.of(context).push(bloomRoute(const WeightHistoryScreen())),
          ),
          GroupRow(
            leading: const _RowIcon(Icons.local_florist_outlined),
            title: 'Plan report',
            caption: best == null ? 'Tick a rule to start the report' : 'Best: ${best.$1.title.toLowerCase()}, ${best.$2} ${best.$2 == 1 ? 'day' : 'days'}',
            onTap: () => Navigator.of(context).push(bloomRoute(const PlanReportScreen())),
            last: true,
          ),
        ]),
        const SizedBox(height: 20),
        const Eyebrow('Settings'),
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
          ),
          GroupRow(
            title: 'Units',
            caption: profile.pounds ? 'Pounds' : 'Kilograms',
            trailing: SizedBox(
              width: 120,
              child: SegmentedSwitch(labels: const ['kg', 'lb'], index: profile.pounds ? 1 : 0, onChanged: (i) => update(profile.copyWith(pounds: i == 1))),
            ),
          ),
          const GroupRow(title: 'Account', caption: 'Guest · everything stays on this phone', last: true),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rLg)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bloom Plus', style: BloomText.headline.copyWith(color: BloomColors.forest)),
                Text('All 40 moves and new outfits for ${profile.catName}.', style: BloomText.body.copyWith(fontSize: 14, height: 20 / 14)),
              ]),
            ),
            const SizedBox(width: 12),
            LedgeButton(label: 'Try 7 days', expand: false, onPressed: () => showBloomSheet<void>(context, (c) => const _PlusSoonSheet())),
          ]),
        ),
      ],
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
        child: Icon(icon, color: BloomColors.sageDeep, size: 22),
      );
}

class _NamesSheet extends ConsumerStatefulWidget {
  const _NamesSheet();
  @override
  ConsumerState<_NamesSheet> createState() => _NamesSheetState();
}

class _NamesSheetState extends ConsumerState<_NamesSheet> {
  late final _you = TextEditingController(text: ref.read(profileProvider).name);
  late final _cat = TextEditingController(text: ref.read(profileProvider).catName);

  @override
  void dispose() {
    _you.dispose();
    _cat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Names', style: BloomText.title),
        const SizedBox(height: 16),
        _Field(label: 'Your name', controller: _you, hint: 'e.g. Sam'),
        const SizedBox(height: 12),
        _Field(label: 'Her name', controller: _cat, hint: 'Clover'),
        const SizedBox(height: 20),
        LedgeButton(
          label: 'Save names',
          onPressed: () {
            final p = ref.read(profileProvider);
            final cat = _cat.text.trim();
            ref.read(profileProvider.notifier).update(p.copyWith(name: _you.text.trim(), catName: cat.isEmpty ? 'Clover' : cat));
            Navigator.of(context).pop();
          },
        ),
      ]);
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.hint});
  final String label, hint;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: BloomText.headline.copyWith(fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          style: BloomText.headline,
          cursorColor: BloomColors.forest,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: BloomText.headline.copyWith(color: BloomColors.inkMuted),
            filled: true,
            fillColor: BloomColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.lineStrong, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.forest, width: 2)),
          ),
        ),
      ]);
}

/// Bloom Plus isn't on sale yet; say so plainly instead of a fake checkout.
class _PlusSoonSheet extends StatelessWidget {
  const _PlusSoonSheet();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(BloomSpace.rLg),
          child: Image.asset('assets/scenes/gift.jpg', height: 180, fit: BoxFit.cover, alignment: const Alignment(0, .3)),
        ),
        const SizedBox(height: 16),
        Text('Bloom Plus is on its way', style: BloomText.title),
        const SizedBox(height: 6),
        for (final p in const ['All 40 moves, with every piece of gear', 'Weekly summary and plan report', 'New outfits and room decor'])
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: BloomColors.forest, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(p, style: BloomText.body)),
            ]),
          ),
        const SizedBox(height: 20),
        LedgeButton(label: 'Got it', variant: LedgeVariant.secondary, onPressed: () => Navigator.of(context).pop()),
      ].map((w) => w is SizedBox ? w : RiseIn(delay: BloomMotion.stagger, child: w)).toList());
}
