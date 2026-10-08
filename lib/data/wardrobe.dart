import 'package:flutter/foundation.dart';

import 'equipment.dart';

/// Where on her an outfit goes; she wears one per slot.
enum OutfitSlot {
  head('Head'),
  eyes('Eyes'),
  neck('Neck'),
  body('Body');

  const OutfitSlot(this.label);
  final String label;
}

/// Something for Clover to wear. Just for fun: outfits unlock nothing.
class Outfit extends ShopItem {
  const Outfit({required super.id, required super.name, required this.slot, required super.price, required super.blurb, super.plus});
  final OutfitSlot slot;
}

/// Something for her room.
class Decor extends ShopItem {
  const Decor({required super.id, required super.name, required super.price, required super.blurb, super.plus});
}

const outfitCatalog = <Outfit>[
  Outfit(id: 'o_sweatband', name: 'Sweatband', slot: OutfitSlot.head, price: 60, blurb: 'Ready to sweat!'),
  Outfit(id: 'o_bandana', name: 'Bandana', slot: OutfitSlot.neck, price: 80, blurb: 'A little bit cowboy.'),
  Outfit(id: 'o_glasses', name: 'Round glasses', slot: OutfitSlot.eyes, price: 90, blurb: 'Very scholarly.'),
  Outfit(id: 'o_bowtie', name: 'Bow tie', slot: OutfitSlot.neck, price: 110, blurb: 'Fancy, aren’t I?'),
  Outfit(id: 'o_cap', name: 'Sunny cap', slot: OutfitSlot.head, price: 120, blurb: 'Shade on, game on.'),
  Outfit(id: 'o_shades', name: 'Shades', slot: OutfitSlot.eyes, price: 160, blurb: 'Too cool for cardio.'),
  Outfit(id: 'o_beanie', name: 'Bobble beanie', slot: OutfitSlot.head, price: 180, blurb: 'Toasty ears!'),
  Outfit(id: 'o_scarf', name: 'Cosy scarf', slot: OutfitSlot.neck, price: 240, blurb: 'So soft!', plus: true),
  Outfit(id: 'o_crown', name: 'Flower crown', slot: OutfitSlot.head, price: 280, blurb: 'Queen of the balcony.', plus: true),
  Outfit(id: 'o_hoodie', name: 'Clay hoodie', slot: OutfitSlot.body, price: 320, blurb: 'Hoodie season!', plus: true),
  Outfit(id: 'o_tracksuit', name: 'Track jacket', slot: OutfitSlot.body, price: 400, blurb: 'Dressed for a personal best.', plus: true),
];

const decorCatalog = <Decor>[
  Decor(id: 'd_plant', name: 'Plant pot', price: 80, blurb: 'A little green by the window.'),
  Decor(id: 'd_poster', name: 'Wall poster', price: 100, blurb: 'Something cheery on the wall.'),
  Decor(id: 'd_rug', name: 'Round rug', price: 120, blurb: 'Soft under her paws.'),
  Decor(id: 'd_lamp', name: 'Reading lamp', price: 140, blurb: 'A warm glow for story time.'),
  Decor(id: 'd_beanbag', name: 'Bean bag', price: 300, blurb: 'The comfiest flop in the house.', plus: true),
  Decor(id: 'd_cattree', name: 'Cat tree', price: 380, blurb: 'Three floors of lookout.', plus: true),
  Decor(id: 'd_aquarium', name: 'Aquarium', price: 450, blurb: 'Hours of fish TV.', plus: true),
  Decor(id: 'd_record', name: 'Record player', price: 520, blurb: 'Slow songs for slow evenings.', plus: true),
];

/// What Clover has on, as the scenes' rig reads it: per slot, the 1-based place of the item among that
/// slot's outfits in [outfitCatalog] (0 = nothing). Kept current from the saved wardrobe (see BloomApp).
class Worn {
  static final current = ValueNotifier<Map<OutfitSlot, int>>(const {});

  /// The rig's number for each slot, from slot name -> outfit id.
  static Map<OutfitSlot, int> of(Map<String, String> worn) => {
        for (final slot in OutfitSlot.values)
          slot: () {
            final id = worn[slot.name];
            final i = outfitCatalog.where((o) => o.slot == slot).toList().indexWhere((o) => o.id == id);
            return i < 0 ? 0 : i + 1;
          }(),
      };
}
