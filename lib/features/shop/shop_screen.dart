import 'package:flutter/material.dart';

import '../../app/feel.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/equipment.dart';
import '../../data/premium.dart';
import '../../data/today.dart';
import '../../data/wardrobe.dart';
import '../../ui/clover_rive.dart';
import '../../ui/clover_scene.dart';
import '../../ui/gear_art.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/room_frame.dart';
import '../today/flow.dart';
import '../paywall/paywall_screen.dart';
import 'unlocked_screen.dart';

/// The garage gym. Gear bought with paws unlocks new moves for both of you.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  int _tab = 0;
  OutfitSlot? _slot;

  /// What she said about the last thing bought, until the tab changes.
  String? _said;

  /// Owned items sink to the end; the rest stays cheapest first.
  List<T> _sorted<T extends ShopItem>(List<T> list, TodayState s) => [...list]
    ..sort((a, b) {
      final oa = s.owns(a.id) ? 1 : 0, ob = s.owns(b.id) ? 1 : 0;
      return oa != ob ? oa - ob : a.price - b.price;
    });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(todayProvider);
    final plus = ref.watch(premiumProvider).active;
    final gear = _sorted(equipmentCatalog, s);
    final outfits = _sorted(outfitCatalog.where((o) => _slot == null || o.slot == _slot).toList(), s);
    final decor = _sorted(decorCatalog, s);
    final next = gear.where((e) => !s.owns(e.id) && (plus || !e.plus)).firstOrNull;
    final line = _said ??
        switch (_tab) {
          1 => 'Dress me up? Pretty please!',
          2 => 'Let’s make my room cosy!',
          _ => next == null
              ? 'The gym is complete. Look at us!'
              : s.paws >= next.price
                  ? 'Ooh, the ${next.name.toLowerCase()}! Can we?'
                  : '${next.price - s.paws} more paws for the ${next.name.toLowerCase()}!',
        };
    Widget card(ShopItem item, int i) => RiseIn(
          delay: Duration(milliseconds: 40 * i),
          child: _ItemCard(
            item: item,
            owned: s.owns(item.id),
            wearing: item is Outfit && s.worn[item.slot.name] == item.id,
            paws: s.paws,
            locked: item.plus && !plus,
            onBuy: () => _confirm(item),
            onPlus: _plus,
            onWear: item is Outfit ? () => _wear(item) : null,
          ),
        );
    return RoomFrame(
      asset: 'assets/scenes/garage.jpg',
      scene: CloverScene.gym,
      action: CloverAction.gymJacks,
      room: Room.shop,
      line: line,
      title: 'Shop',
      panel: _tab,
      line2: 'Every move we do earns us paws.',
      subtitle: Text(
        switch (_tab) {
          1 => 'Something for her to wear, just for fun.',
          2 => 'Make her room your own.',
          _ => 'Gear unlocks new moves for you both.',
        },
        style: BloomText.bodyMuted.copyWith(fontSize: 15),
      ),
      showPaws: true,
      bubbleLeft: 16,
      // The scene, title and the switch stay put; only the items scroll, under them.
      pinned: [
        SegmentedSwitch(labels: const ['Equipment', 'Outfits', 'Room decor'], index: _tab, onChanged: _setTab),
      ],
      children: [
        SwipePanels(
          index: _tab,
          count: 3,
          onChanged: _setTab,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            transitionBuilder: (c, a) => panelTransition(c, a),
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                1 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _SlotChips(slot: _slot, onChanged: (v) => setState(() => _slot = v)),
                    const SizedBox(height: 14),
                    _Grid(key: ValueKey(_slot), children: [for (final (i, o) in outfits.indexed) card(o, i)]),
                  ]),
                2 => _Grid(children: [for (final (i, d) in decor.indexed) card(d, i)]),
                _ => _Grid(children: [for (final (i, e) in gear.indexed) card(e, i)]),
              },
            ),
          ),
        ),
      ],
    );
  }

  void _setTab(int i) => setState(() {
        _tab = i;
        _said = null;
      });

  void _plus() {
    Feel.selectionClick();
    Navigator.of(context).push(bloomRoute(Builder(builder: (c) => Scaffold(body: PaywallScreen(onDone: () => Navigator.of(c).pop())))));
  }

  void _wear(Outfit o) {
    Feel.selectionClick();
    final on = ref.read(todayProvider).worn[o.slot.name] != o.id;
    ref.read(todayProvider.notifier).wear(o);
    SfxPlayer.instance.play(on ? Sfx.check : Sfx.uncheck);
    setState(() => _said = on ? o.blurb : null);
  }

  Future<void> _confirm(ShopItem item) async {
    Feel.selectionClick();
    final bought = await showBloomSheet<bool>(context, (context) => _BuySheet(item: item));
    if (bought != true || !mounted) return;
    SfxPlayer.instance.play(Sfx.unlock);
    if (item is Equipment) {
      await Navigator.of(context).push(bloomRoute(UnlockedScreen(item: item)));
    } else {
      Feel.mediumImpact();
      setState(() => _said = item is Outfit ? item.blurb : 'Ooh, the ${item.name.toLowerCase()}! It’s perfect.');
    }
  }
}

/// All, or one slot: head, eyes, neck, body.
class _SlotChips extends StatelessWidget {
  const _SlotChips({required this.slot, required this.onChanged});
  final OutfitSlot? slot;
  final ValueChanged<OutfitSlot?> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (i, v) in <OutfitSlot?>[null, ...OutfitSlot.values].indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Semantics(
              button: true,
              selected: v == slot,
              child: GestureDetector(
                onTap: () {
                  Feel.selectionClick();
                  onChanged(v);
                },
                child: AnimatedContainer(
                  duration: BloomMotion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: v == slot ? BloomColors.ink : BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                  child: Text(v?.label ?? 'All', style: BloomText.button.copyWith(fontSize: 14, color: v == slot ? BloomColors.surface : BloomColors.ink)),
                ),
              ),
            ),
          ],
        ]),
      );
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

/// One thing for sale. Gear says what it unlocks; outfits can be worn once bought; Plus items show a
/// lock to Bloom Plus until it's on.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.owned,
    required this.wearing,
    required this.paws,
    required this.locked,
    required this.onBuy,
    required this.onPlus,
    this.onWear,
  });
  final ShopItem item;
  final bool owned, wearing, locked;
  final int paws;
  final VoidCallback onBuy, onPlus;
  final VoidCallback? onWear;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final can = !owned && !locked && paws >= item.price;
    final short = '${PawChipState.fmt(item.price - paws)} more paws';
    // A locked Plus card says so once, with its tag; no line under the name.
    final sub = switch (item) {
      _ when locked && !owned => null,
      Equipment(:final unlocks) => owned ? 'Owned · ${unlocks.length} moves' : (can ? 'Unlocks ${unlocks.length} moves' : short),
      Outfit(:final slot) => owned ? (wearing ? 'Wearing · ${slot.label.toLowerCase()}' : slot.label) : (can ? slot.label : short),
      _ => owned ? 'In her room' : (can ? 'For her room' : short),
    };
    final Widget button;
    if (owned && onWear != null) {
      button = wearing
          ? LedgeButton(label: 'Wearing', leading: const Icon(Icons.check_rounded, color: BloomColors.onForest, size: 20), onPressed: onWear)
          : LedgeButton(label: 'Wear', variant: LedgeVariant.secondary, onPressed: onWear);
    } else if (owned) {
      button = const LedgeButton(label: 'Owned', onPressed: null, variant: LedgeVariant.secondary);
    } else if (locked) {
      // The price, behind a lock until Bloom Plus is on.
      button = LedgeButton(
        label: PawChipState.fmt(item.price),
        variant: LedgeVariant.secondary,
        leading: const Icon(Icons.lock_rounded, color: BloomColors.ink, size: 18),
        onPressed: onPlus,
      );
    } else {
      button = LedgeButton(
        label: PawChipState.fmt(item.price),
        variant: LedgeVariant.reward,
        glow: can,
        leading: PawIcon(size: 18, color: can ? BloomColors.ink : BloomColors.mustard),
        onPressed: can ? onBuy : null,
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: item.plus ? BloomColors.forestSoft : BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 22, 14, 12),
                      child: Opacity(opacity: locked && !owned ? .75 : 1, child: GearArt(id: item.id)),
                    ),
                  ),
                  if (owned)
                    const Positioned(left: 8, top: 8, child: _Tag('OWNED'))
                  else if (item.plus)
                    const Positioned(left: 8, top: 8, child: _Tag('PLUS', plus: true)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(item.name, style: BloomText.headline.copyWith(fontSize: 16, height: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
          // Kept as a blank line when empty, so names line up across the row.
          Text(sub ?? '', style: BloomText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          SizedBox(height: 44, child: button),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.plus = false});
  final String text;
  final bool plus;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: plus ? BloomColors.forest : BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (plus) ...[const Icon(Icons.auto_awesome_rounded, size: 12, color: BloomColors.onForest), const SizedBox(width: 3)],
      Text(text, style: BloomText.label.copyWith(color: plus ? BloomColors.onForest : BloomColors.forest, letterSpacing: .6)),
    ]),
  );
}

/// "Get the jump rope?" The balance shows what it will be after.
class _BuySheet extends ConsumerWidget {
  const _BuySheet({required this.item});
  final ShopItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paws = ref.watch(todayProvider.select((s) => s.paws));
    final item = this.item;
    final what = switch (item) {
      Equipment(:final unlocks) => 'Unlocks ${unlocks.map((e) => e.name).join(' and ')} for you both.',
      Outfit(:final blurb) => '$blurb She’ll put it on straight away.',
      _ => item.blurb,
    };
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
                  Text(what, style: BloomText.bodyMuted.copyWith(fontSize: 15, height: 1.4)),
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
