import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/coat.dart';
import '../../data/journal.dart';
import '../../data/premium.dart';
import '../../data/today.dart';
import '../../data/profile.dart';
import '../../ui/painted_icon.dart';
import '../../ui/bits.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/window_sky.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../../ui/title_pill.dart';
import '../../ui/weight_chart.dart';
import '../paywall/paywall_screen.dart';
import '../today/flow.dart';
import 'cat_picker.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

/// The bedroom, the "You" tab: four tiles for what you change most (your cat, your goal, Bloom Plus, reminders),
/// then a short settings list. Names are edited from the title row. (Stats and reports live in Progress.)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final journal = ref.watch(journalProvider);
    final premium = ref.watch(premiumProvider);
    final days = journal.dayNumber;
    final hour = DateTime.now().hour;
    final line = hour >= 20 || hour < 5 ? 'Story time, then sleep.' : (hour < 11 ? 'Five more minutes…' : 'My comfy corner!');
    void push(Widget w) => Navigator.of(context).push(bloomRoute(w));
    final goal = profile.reason.isEmpty ? 'Moving together' : profile.reason;

    return RoomFrame(
      asset: 'assets/scenes/bedroom.jpg',
      scene: CloverScene.profile,
      action: CloverAction.bedroomTidy,
      room: Room.profile,
      sceneOverlay: const BedroomWindow(),
      line: line,
      line2: 'Thanks for keeping me company.',
      title: '${profile.displayName} & ${profile.catName}',
      // Names are edited from the title row, with the same pill as the other rooms' title buttons.
      titleTrailing: TitlePill(
        icon: const PaintedIcon('pencil', size: TitlePill.artSize),
        label: 'Edit',
        semantics: 'Edit names',
        onTap: () => showBloomSheet<void>(context, (c) => const _NamesSheet()),
      ),
      subtitle: Text(days == 0 ? 'Together since today' : 'Together for ${days + 1} days', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      // As in the other rooms: the bedroom slides away as the page scrolls, and the title docks as a slim bar.
      pinned: const [],
      children: [
        // The four things changed most, as tinted tiles (one structure each: icon, label, value, caption); the rest
        // is a short list.
        Row(children: [
          Expanded(
            child: ValueListenableBuilder<Coat>(
              valueListenable: Coat.current,
              builder: (context, coat, _) => _Tile(
                tint: BloomColors.forestSoft,
                accent: BloomColors.forest,
                icon: ClipOval(child: Image.asset(coat.avatar, fit: BoxFit.cover)),
                label: 'Your cat',
                value: profile.catName,
                caption: '${coat.label} coat',
                onTap: () => showCatPicker(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              tint: BloomColors.paperSunk,
              accent: BloomColors.forest,
              icon: const PaintedIcon('flag', size: 20),
              label: 'Your goal',
              value: goal,
              caption: '$kDailyGoal moves · ${profile.activity == 'Mostly sitting' ? 'gentle' : 'steady'} pace',
              onTap: () => showBloomSheet<void>(context, (c) => const _GoalSheet()),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _Tile(
              tint: BloomColors.mustardSoft,
              accent: const Color(0xFF7A5F12),
              icon: const PaintedIcon('sparkles', size: 20),
              label: 'Bloom Plus',
              value: premium.active ? '${premium.plan?.label ?? 'Plus'} plan' : 'Try 7 days free',
              caption: premium.active && premium.trialEnds != null ? 'Free until ${shortDate(premium.trialEnds!)}' : 'Every move and outfit',
              onTap: () => push(premium.active ? const SubscriptionScreen() : Builder(builder: (c) => Scaffold(body: PaywallScreen(onDone: () => Navigator.of(c).pop())))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              tint: BloomColors.sky,
              accent: BloomColors.skyDeep,
              icon: const PaintedIcon('bell', size: 20),
              label: 'Reminders',
              value: [if (profile.morning) clockText(profile.morningAt), if (profile.evening) clockText(profile.eveningAt)].join(' · ').ifEmpty('Off'),
              caption: profile.morning && profile.evening
                  ? 'Morning and evening'
                  : profile.morning
                      ? 'Morning'
                      : profile.evening
                          ? 'Evening'
                          : 'Turn one on',
              onTap: () => push(const SettingsScreen()),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        GroupCard(children: [
          GroupRow(
            leading: const _RowIcon('speaker'),
            title: 'Sound & haptics',
            caption: [if (profile.sound) 'Sounds', if (profile.haptics) 'haptics'].join(' and ').ifEmpty('Off'),
            onTap: () => push(const SettingsScreen()),
          ),
          GroupRow(
            leading: const _RowIcon('ruler'),
            title: 'Units & widgets',
            caption: profile.pounds ? 'Pounds' : 'Kilograms',
            onTap: () => push(const SettingsScreen()),
          ),
          GroupRow(
            leading: const _RowIcon('gear'),
            title: 'All settings',
            caption: 'Subscription, account, testing',
            onTap: () => push(const SettingsScreen()),
            last: true,
          ),
        ]),
      ],
    );
  }
}

/// A tinted tile, one structure for all four: a top row (a small white disc with the icon, the label in caps, a
/// chevron), then one value line and one caption line at the foot. The whole tile is the button.
class _Tile extends StatelessWidget {
  const _Tile({required this.tint, required this.accent, required this.icon, required this.label, required this.value, required this.caption, required this.onTap});
  final Color tint, accent;
  final Widget icon;
  final String label, value, caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label: $value, $caption',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Feel.selectionClick();
            onTap();
          },
          child: Container(
            height: 112,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(BloomSpace.rLg)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle),
                  child: icon,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label.toUpperCase(), style: BloomText.label.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Icon(Icons.chevron_right_rounded, size: 20, color: accent),
              ]),
              const Spacer(),
              Text(value, style: BloomText.headline.copyWith(fontSize: 17, height: 22 / 17), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(caption, style: BloomText.caption.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// The goal from onboarding, changeable here.
class _GoalSheet extends ConsumerWidget {
  const _GoalSheet();
  static const goals = ['Lose some weight', 'Move more every day', 'Feel lighter and calmer', 'Build better habits'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Your goal', style: BloomText.title),
      const SizedBox(height: 4),
      Text('What matters most to you right now? You can change it any time.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      const SizedBox(height: 14),
      for (final g in goals) ...[
        LedgeButton(
          label: g,
          variant: p.reason == g ? LedgeVariant.primary : LedgeVariant.secondary,
          onPressed: () {
            ref.read(profileProvider.notifier).update(p.copyWith(reason: g));
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  /// A painted icon's name (assets/icons).
  final String icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rSm)),
        child: Center(child: PaintedIcon(icon, size: 30)),
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
