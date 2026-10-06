import 'dart:ui';

import 'perf_probe.dart';

import 'package:flutter/material.dart';

import 'feel.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/plan/plan_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/shop/shop_screen.dart';
import '../features/today/flow.dart';
import '../features/today/today_screen.dart';
import 'motion.dart';
import 'home_widgets.dart';
import 'reminders.dart';
import 'sfx.dart';
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
      body: Stack(
        children: [
          // Every room stays alive so returning is instant; hidden rooms pause.
          for (final r in Room.values)
            Offstage(
              offstage: r != room,
              child: TickerMode(enabled: r == room, child: _roomFor(r)),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: const BloomTabBar(),
          ),
          const _ReminderRouter(),
        ],
      ),
    );
  }

  Widget _roomFor(Room r) => switch (r) {
    Room.today => const TodayScreen(),
    Room.shop => const ShopScreen(),
    Room.plan => const PlanScreen(),
    Room.progress => const ProgressScreen(),
    Room.profile => const ProfileScreen(),
  };
}

/// Floating pill tab bar in liquid glass: the room behind is blurred and saturated through a smoky
/// forest tint, with a bright rim and a top sheen. The open room's frosted pill flows between tabs,
/// stretching as it travels; icons pop on selection.
class BloomTabBar extends ConsumerWidget {
  const BloomTabBar({super.key});

  static const _items = [
    (Room.shop, Icons.shopping_bag_outlined, 'Shop'),
    (Room.plan, Icons.checklist_rounded, 'Plan'),
    (Room.today, Icons.weekend_outlined, 'Today'),
    (Room.progress, Icons.show_chart_rounded, 'Progress'),
    (Room.profile, Icons.person_outline_rounded, 'Profile'),
  ];

  // Saturates what shows through, like light bending in thick glass.
  static final _glass = ImageFilter.compose(
    outer: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
    inner: const ColorFilter.matrix([
      1.36, -.32, -.04, 0, 0, //
      -.08, 1.24, -.04, 0, 0,
      -.08, -.32, 1.48, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider);
    final index = _items.indexWhere((i) => i.$1 == room);
    final radius = BorderRadius.circular(BloomSpace.rPill);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(color: Color(0x472E3826), blurRadius: 28, offset: Offset(0, 14)),
          BoxShadow(color: Color(0x1F2E3826), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: _glass,
          child: CustomPaint(
            painter: const _GlassPainter(),
            foregroundPainter: const _GlassRim(),
            child: SizedBox(
              height: 66,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth / _items.length;
                    return Stack(
                      children: [
                        // The pill glides to the new tab and stretches like a drop on the way.
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: index.toDouble()),
                          duration: const Duration(milliseconds: 460),
                          curve: BloomMotion.spring,
                          builder: (context, pos, _) {
                            final stretch = (index - pos).abs().clamp(0.0, 1.0) * w * .45;
                            return Positioned(
                              left: pos * w - stretch / 2,
                              top: 0,
                              bottom: 0,
                              width: w + stretch,
                              child: const _GlassPill(),
                            );
                          },
                        ),
                        Row(
                          children: [
                            for (final (r, icon, label) in _items)
                              Expanded(
                                child: Semantics(
                                  selected: r == room,
                                  button: true,
                                  label: label,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (r != room) {
                                        Feel.selectionClick();
                                        SfxPlayer.instance.play(Sfx.tap, volume: .5);
                                      }
                                      PerfProbe.tab(r.name);
                                      ref.read(roomProvider.notifier).go(r);
                                    },
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey('$r-${r == room}'),
                                      tween: Tween(begin: r == room ? .7 : 1, end: 1),
                                      duration: const Duration(milliseconds: 420),
                                      curve: BloomMotion.pop,
                                      builder: (context, s, child) => Transform.scale(scale: s, child: child),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(icon, size: 24, color: r == room ? BloomColors.onGlass : BloomColors.onGlassMuted),
                                          const SizedBox(height: 2),
                                          Text(
                                            label,
                                            style: BloomText.label.copyWith(
                                              fontSize: 11,
                                              letterSpacing: .4,
                                              color: r == room ? BloomColors.onGlass : BloomColors.onGlassMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The glass body: the forest tint, deeper at the bottom, with a soft sheen across the top half
/// and a faint caustic glow along the bottom edge.
class _GlassPainter extends CustomPainter {
  const _GlassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(size.height / 2));
    canvas.drawRRect(rr, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [BloomColors.glassTop, BloomColors.glassBottom]).createShader(r));
    final top = Rect.fromLTWH(0, 0, size.width, size.height * .5);
    canvas.drawRRect(
      RRect.fromRectAndCorners(top, topLeft: Radius.circular(size.height / 2), topRight: Radius.circular(size.height / 2)),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)]).createShader(top),
    );
    final glow = Rect.fromLTWH(size.width * .12, size.height * .72, size.width * .76, size.height * .28);
    canvas.drawOval(glow, Paint()..color = const Color(0x1AFFF6D8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  }

  @override
  bool shouldRepaint(_GlassPainter old) => false;
}

/// The bright rim light catches the top-left edge and, more faintly, the bottom-right.
class _GlassRim extends CustomPainter {
  const _GlassRim();

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(size.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB3FFFFFF), Color(0x26FFFFFF), Color(0x14FFFFFF), Color(0x66FFFFFF)],
          stops: [0, .35, .65, 1],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_GlassRim old) => false;
}

/// The open room's pill: frosted, lighter glass with its own highlight.
class _GlassPill extends StatelessWidget {
  const _GlassPill();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BloomSpace.rPill),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x47FFFBF3), BloomColors.glassPill]),
          border: Border.all(color: const Color(0x59FFFFFF), width: 1),
          boxShadow: const [BoxShadow(color: Color(0x261A2414), blurRadius: 8, offset: Offset(0, 2))],
        ),
      );
}

/// Opening the app from a reminder goes to the right room: the morning one to
/// the plan, the evening one to Today with the check-in open.
class _ReminderRouter extends ConsumerStatefulWidget {
  const _ReminderRouter();
  @override
  ConsumerState<_ReminderRouter> createState() => _ReminderRouterState();
}

class _ReminderRouterState extends ConsumerState<_ReminderRouter> {
  late final _widgets = HomeWidgetSync(ref);

  @override
  void initState() {
    super.initState();
    _widgets.start();
    Reminders.tapped.addListener(_route);
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  @override
  void dispose() {
    Reminders.tapped.removeListener(_route);
    super.dispose();
  }

  void _route() {
    final which = Reminders.tapped.value;
    if (which == null || !mounted) return;
    Reminders.tapped.value = null;
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (which == 'morning') {
      ref.read(roomProvider.notifier).go(Room.plan);
    } else {
      ref.read(roomProvider.notifier).go(Room.today);
      ref.read(checkInRequestProvider.notifier).ask();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
