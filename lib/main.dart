import 'app/move_tour.dart';
import 'app/perf_probe.dart';
import 'app/perf_tour.dart';

import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/gate.dart';
import 'app/idle.dart';
import 'data/alarms.dart';
import 'data/coat.dart';
import 'data/premium.dart';
import 'data/profile.dart';
import 'data/today.dart';
import 'data/wardrobe.dart';
import 'features/alarm/ringing_screen.dart';
import 'app/reminders.dart';
import 'app/sfx.dart';
import 'app/theme.dart';
import 'ui/clover_rive.dart';
import 'ui/fx_layer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Idle.start();
  // Room art is large; keep decoded images to a modest budget so memory stays low on smaller phones.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 << 20;
  // Portrait only: every room is composed for a tall screen.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await CloverRive.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  SfxPlayer.instance.init();
  Reminders.init();
  try {
    await Alarm.init();
  } catch (e) {
    debugPrint('Alarms unavailable: $e');
  }
  PerfProbe.start();
  runApp(const ProviderScope(child: BloomApp()));
}

/// Lets the ringing screen open over whatever is on screen.
final _navigator = GlobalKey<NavigatorState>();

class BloomApp extends ConsumerStatefulWidget {
  const BloomApp({super.key});

  @override
  ConsumerState<BloomApp> createState() => _BloomAppState();
}

class _BloomAppState extends ConsumerState<BloomApp> {
  StreamSubscription<AlarmSet>? _ringing;
  final _showing = <int>{};

  @override
  void initState() {
    super.initState();
    // Loads saved alarms and re-arms them.
    ref.read(alarmsProvider);
    // The scenes draw the chosen cat while Bloom Plus is on; without it, Clover.
    void cat() {
      // COAT=fold|calico (a --dart-define) forces a cat, for checking the scenes on a device.
      const forced = String.fromEnvironment('COAT');
      final coat = Coat.values.asNameMap()[forced] ?? ref.read(profileProvider).coat;
      if (forced.isNotEmpty) {
        Coat.current.value = coat;
        return;
      }
      Coat.current.value = coat.plus && !ref.read(premiumProvider).active ? Coat.clover : coat;
    }
    ref.listenManual(profileProvider.select((p) => p.coat), (_, _) => cat(), fireImmediately: true);
    ref.listenManual(premiumProvider.select((p) => p.active), (_, _) => cat(), fireImmediately: true);
    // What she wears shows in every scene. WEAR=o_beanie,o_scarf (a --dart-define) dresses her for checks.
    const wear = String.fromEnvironment('WEAR');
    void dress(Map<String, String> worn) {
      final forced = {for (final o in outfitCatalog) if (wear.split(',').contains(o.id)) o.slot.name: o.id};
      Worn.current.value = Worn.of(wear.isEmpty ? worn : forced);
    }
    ref.listenManual(todayProvider.select((s) => s.worn), (_, w) => dress(w), fireImmediately: true);
    // After the first frame, so startup isn't slowed by it.
    WidgetsBinding.instance.addPostFrameCallback((_) => CloverRive.preload());
    PerfTour.run(_navigator, ref);
    MoveTour.run(_navigator);
    try {
      _ringing = Alarm.ringing.listen((set) {
        for (final a in set.alarms) {
          if (_showing.add(a.id)) _openRinging(a.id);
        }
      });
    } catch (_) {}
  }

  Future<void> _openRinging(int id) async {
    final nav = _navigator.currentState;
    if (nav == null) return;
    await nav.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => RingingScreen(alarmId: id),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    _showing.remove(id);
  }

  @override
  void dispose() {
    _ringing?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom',
      navigatorKey: _navigator,
      navigatorObservers: [PerfProbe.observer],
      debugShowCheckedModeBanner: false,
      theme: bloomTheme(),
      builder: (context, child) => FxLayer.wrap(child!),
      home: const AppGate(),
    );
  }
}
