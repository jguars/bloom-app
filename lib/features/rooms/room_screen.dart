import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/today.dart';
import '../../ui/paw.dart';
import '../../ui/scene.dart';
import '../../ui/speech_bubble.dart';

/// A room of the house that isn't built yet: its scene, its title, and a line
/// from Clover. Shop also shows the paws balance (the only room besides Today
/// that does).
class RoomInfo {
  const RoomInfo(this.title, this.asset, this.line, this.subtitle, {this.showPaws = false});
  final String title, asset, line, subtitle;
  final bool showPaws;

  static const shop = RoomInfo('Shop', 'assets/scenes/garage.jpg', 'Ooh, a jump rope!', 'Gear unlocks new moves for you both.', showPaws: true);
  static const plan = RoomInfo('Plan', 'assets/scenes/balcony.jpg', 'Watering our good habits!', 'Your do-more and skip lists.');
  static const progress = RoomInfo('Progress', 'assets/scenes/hallway.jpg', 'Look how far we’ve come!', 'Your weight and her journey.');
  static const profile = RoomInfo('Profile', 'assets/scenes/bedroom.jpg', 'Story time, then sleep.', 'You, Clover and settings.');
}

class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key, required this.room});
  final RoomInfo room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.of(context).padding.top;
    final paws = ref.watch(todayProvider.select((s) => s.paws));
    final sceneH = 300.0 + top * .5;
    return ColoredBox(
      color: BloomColors.surface,
      child: Stack(fit: StackFit.expand, children: [
        Positioned(left: 0, right: 0, top: 0, child: Scene(asset: room.asset, height: sceneH, fadeHeight: 62)),
        Positioned(left: 16, top: top + 18, child: SpeechBubble(text: room.line)),
        if (room.showPaws) Positioned(right: 16, top: top + 12, child: PawChip(paws: paws)),
        Positioned.fill(
          top: sceneH - 30,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RiseIn(child: Text(room.title, style: BloomText.display)),
              const SizedBox(height: 4),
              RiseIn(delay: const Duration(milliseconds: 80), child: Text(room.subtitle, style: BloomText.bodyMuted)),
              const SizedBox(height: 20),
              RiseIn(
                delay: const Duration(milliseconds: 160),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rLg)),
                  child: Text('This room is being decorated. For now, Today has everything you need.', style: BloomText.bodyMuted),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
