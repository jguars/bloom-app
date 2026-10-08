import 'package:flutter/material.dart';

import '../../app/feel.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sfx.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/equipment.dart';
import '../../data/today.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/gear_art.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/room_frame.dart';
import '../today/flow.dart';
import 'unlocked_screen.dart';

/// The garage gym. Gear bought with paws unlocks new moves for both of you.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(todayProvider);
    // Owned gear sinks to the end; the rest stays cheapest first.
    final items = [...equipmentCatalog]
      ..sort((a, b) {
        final oa = s.owns(a.id) ? 1 : 0, ob = s.owns(b.id) ? 1 : 0;
        return oa != ob ? oa - ob : a.price - b.price;
      });
    final next = items.where((e) => !s.owns(e.id)).firstOrNull;
    final line = next == null
        ? 'The gym is complete. Look at us!'
        : s.paws >= next.price
        ? 'Ooh, the ${next.name.toLowerCase()}! Can we?'
        : '${next.price - s.paws} more paws for the ${next.name.toLowerCase()}!';
    return RoomFrame(
      asset: 'assets/scenes/garage.jpg',
      scene: CloverScene.gym,
      action: CloverAction.gymJacks,
      room: Room.shop,
      line: line,
      title: 'Shop',
      line2: 'Every move we do earns us paws.',
      subtitle: Text('Gear unlocks new moves for you both.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      showPaws: true,
      bubbleLeft: 16,
      // The scene, title and the switch stay put; only the items scroll, under them.
      pinned: [
        SegmentedSwitch(labels: const ['Equipment', 'Room decor'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
      ],
      children: [
        SwipePanels(
          index: _tab,
          count: 2,
          onChanged: (i) => setState(() => _tab = i),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            transitionBuilder: (c, a) => panelTransition(c, a),
            child: _tab == 0
                ? _Grid(
                    key: const ValueKey(0),
                    children: [
                      for (final (i, e) in items.indexed)
                        RiseIn(
                          delay: Duration(milliseconds: 40 * i),
                          child: _GearCard(item: e, owned: s.owns(e.id), paws: s.paws, onBuy: () => _confirm(e)),
                        ),
                    ],
                  )
                : _Grid(
                    key: const ValueKey(1),
                    children: [
                      for (final (i, d) in const [
                        ('Plant pot', Icons.local_florist_outlined),
                        ('Reading lamp', Icons.light_outlined),
                        ('Round rug', Icons.circle_outlined),
                        ('Wall poster', Icons.image_outlined),
                      ].indexed)
                        RiseIn(
                          delay: Duration(milliseconds: 40 * i),
                          child: _DecorCard(name: d.$1, icon: d.$2),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(Equipment item) async {
    Feel.selectionClick();
    final bought = await showBloomSheet<bool>(context, (context) => _BuySheet(item: item));
    if (bought != true || !mounted) return;
    SfxPlayer.instance.play(Sfx.unlock);
    await Navigator.of(context).push(bloomRoute(UnlockedScreen(item: item)));
  }
}

class _Grid extends StatelessWidget {
  const _Grid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: .66,
    padding: EdgeInsets.zero,
    children: children,
  );
}

BoxDecoration get _cardDeco => BoxDecoration(
  color: BloomColors.surface,
  borderRadius: BorderRadius.circular(BloomSpace.rLg),
  boxShadow: const [
    BoxShadow(color: BloomColors.line, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10)),
  ],
);

class _GearCard extends StatelessWidget {
  const _GearCard({required this.item, required this.owned, required this.paws, required this.onBuy});
  final Equipment item;
  final bool owned;
  final int paws;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final can = !owned && paws >= item.price;
    final sub = owned
        ? 'Owned · ${item.unlocks.length} moves'
        : can
        ? 'Unlocks ${item.unlocks.length} moves'
        : '${PawChipState.fmt(item.price - paws)} more paws';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
              child: Stack(
                children: [
                  Center(child: GearArt(id: item.id)),
                  if (owned) const Positioned(left: 8, top: 8, child: _Tag('OWNED')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(item.name, style: BloomText.headline.copyWith(fontSize: 16, height: 1.25)),
          Text(sub, style: BloomText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: owned
                ? const LedgeButton(label: 'Owned', onPressed: null, variant: LedgeVariant.secondary)
                : LedgeButton(
                    label: PawChipState.fmt(item.price),
                    variant: LedgeVariant.reward,
                    glow: can,
                    leading: PawIcon(size: 18, color: can ? BloomColors.ink : BloomColors.mustard),
                    onPressed: can ? onBuy : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DecorCard extends StatelessWidget {
  const _DecorCard({required this.name, required this.icon});
  final String name;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: _cardDeco,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
            child: Icon(icon, size: 40, color: BloomColors.inkMuted),
          ),
        ),
        const SizedBox(height: 10),
        Text(name, style: BloomText.headline.copyWith(fontSize: 16, height: 1.25)),
        Text('For her room', style: BloomText.caption),
        const SizedBox(height: 10),
        const SizedBox(height: 44, child: LedgeButton(label: 'Soon', onPressed: null)),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
    child: Text(text, style: BloomText.label.copyWith(color: BloomColors.forest, letterSpacing: .6)),
  );
}

/// "Get the jump rope?" The balance shows what it will be after.
class _BuySheet extends ConsumerWidget {
  const _BuySheet({required this.item});
  final Equipment item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paws = ref.watch(todayProvider.select((s) => s.paws));
    final moves = item.unlocks.map((e) => e.name).join(' and ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            PopIn(
              child: Container(
                width: 96,
                height: 80,
                decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
                child: Center(child: GearArt(id: item.id, width: 72)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get the ${item.name.toLowerCase()}?', style: BloomText.title),
                  Text('Unlocks $moves for you both.', style: BloomText.bodyMuted.copyWith(fontSize: 15, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rLg)),
          child: Row(
            children: [
              Text('Your paws', style: BloomText.caption.copyWith(fontSize: 14)),
              const Spacer(),
              const PawIcon(size: 20),
              const SizedBox(width: 6),
              Text(PawChipState.fmt(paws), style: BloomText.number.copyWith(fontSize: 18)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: BloomColors.inkMuted, semanticLabel: 'to'),
              ),
              Text(PawChipState.fmt(paws - item.price), style: BloomText.number.copyWith(fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LedgeButton(
          label: 'Get it for ${PawChipState.fmt(item.price)}',
          variant: LedgeVariant.reward,
          glow: true,
          leading: const PawIcon(size: 20, color: BloomColors.ink),
          onPressed: () {
            final ok = ref.read(todayProvider.notifier).buy(item);
            Navigator.of(context).pop(ok);
          },
        ),
        const SizedBox(height: 6),
        Center(
          child: LedgeButton(label: 'Not now', variant: LedgeVariant.ghost, expand: false, onPressed: () => Navigator.of(context).pop(false)),
        ),
      ],
    );
  }
}
