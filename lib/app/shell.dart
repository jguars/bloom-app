import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/rooms/room_screen.dart';
import '../features/today/today_screen.dart';
import 'motion.dart';
import 'theme.dart';

/// The house: five rooms behind one floating tab bar.
enum Room { shop, plan, today, progress, profile }

final roomProvider = NotifierProvider<RoomNotifier, Room>(RoomNotifier.new);

class RoomNotifier extends Notifier<Room> {
  @override
  Room build() => Room.today;
  void go(Room r) => state = r;
}

class Shell extends ConsumerWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider);
    return Scaffold(
      backgroundColor: BloomColors.paper,
      body: Stack(children: [
        // Every room stays alive so returning is instant; hidden rooms pause.
        for (final r in Room.values)
          Offstage(
            offstage: r != room,
            child: TickerMode(enabled: r == room, child: _roomFor(r)),
          ),
        Positioned(left: 16, right: 16, bottom: 16 + MediaQuery.of(context).padding.bottom, child: const BloomTabBar()),
      ]),
    );
  }

  Widget _roomFor(Room r) => switch (r) {
        Room.today => const TodayScreen(),
        Room.shop => const RoomScreen(room: RoomInfo.shop),
        Room.plan => const RoomScreen(room: RoomInfo.plan),
        Room.progress => const RoomScreen(room: RoomInfo.progress),
        Room.profile => const RoomScreen(room: RoomInfo.profile),
      };
}

/// Floating pill tab bar. The active tab gets a forest-soft pill that slides
/// between tabs; icons pop on selection.
class BloomTabBar extends ConsumerWidget {
  const BloomTabBar({super.key});

  static const _items = [
    (Room.shop, Icons.shopping_bag_outlined, 'Shop'),
    (Room.plan, Icons.checklist_rounded, 'Plan'),
    (Room.today, Icons.weekend_outlined, 'Today'),
    (Room.progress, Icons.show_chart_rounded, 'Progress'),
    (Room.profile, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider);
    final index = _items.indexWhere((i) => i.$1 == room);
    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: BloomColors.surface,
        borderRadius: BorderRadius.circular(BloomSpace.rPill),
        boxShadow: const [BoxShadow(color: Color(0x292E3826), blurRadius: 32, offset: Offset(0, 12))],
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / _items.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: BloomMotion.spring,
            left: index * w,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(decoration: BoxDecoration(color: BloomColors.forestSoft, borderRadius: BorderRadius.circular(BloomSpace.rPill))),
          ),
          Row(children: [
            for (final (r, icon, label) in _items)
              Expanded(
                child: Semantics(
                  selected: r == room,
                  button: true,
                  label: label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (r != room) HapticFeedback.selectionClick();
                      ref.read(roomProvider.notifier).go(r);
                    },
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('$r-${r == room}'),
                      tween: Tween(begin: r == room ? .7 : 1, end: 1),
                      duration: const Duration(milliseconds: 420),
                      curve: BloomMotion.pop,
                      builder: (context, s, child) => Transform.scale(scale: s, child: child),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(icon, size: 24, color: r == room ? BloomColors.forest : BloomColors.inkMuted),
                        const SizedBox(height: 2),
                        Text(label, style: BloomText.label.copyWith(fontSize: 11, letterSpacing: .4, color: r == room ? BloomColors.forest : BloomColors.inkMuted)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}
