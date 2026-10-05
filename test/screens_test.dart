import 'dart:io';

import 'package:bloom/app/shell.dart';
import 'package:bloom/app/theme.dart';
import 'package:bloom/data/exercises.dart';
import 'package:bloom/data/today.dart';
import 'package:bloom/features/today/celebration_screen.dart';
import 'package:bloom/features/today/ready_screen.dart';
import 'package:bloom/features/today/session_screen.dart';
import 'package:bloom/ui/fx_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders key screens to test/shots/*.png so layouts can be checked by eye.
/// Run: flutter test --update-goldens test/screens_test.dart
Future<void> _fonts() async {
  final f = FontLoader('Nunito')..addFont(rootBundle.load('assets/fonts/Nunito-Variable.ttf'));
  await f.load();
  final m = FontLoader('MaterialIcons')..addFont(File('${Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/development/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  await m.load();
}

Future<void> _shot(WidgetTester tester, String name, Widget home, {List<String> assets = const []}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(theme: bloomTheme(), debugShowCheckedModeBanner: false, builder: (c, child) => FxLayer.wrap(child!), home: home),
  ));
  await tester.runAsync(() async {
    for (final a in assets) {
      await precacheImage(AssetImage(a), tester.element(find.byType(MaterialApp)));
    }
  });
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
}

void main() {
  setUpAll(_fonts);
  const ex = Exercise(id: 'march', name: 'March in place', seconds: 120, effort: 1, cues: ['Knees up! Like this!']);
  testWidgets('today', (t) => _shot(t, 'today', const Shell(), assets: ['assets/scenes/living.jpg']));
  testWidgets('ready', (t) => _shot(t, 'ready', const ReadyScreen(ex: ex), assets: ['assets/scenes/ready.jpg']));
  testWidgets('session', (t) => _shot(t, 'session', const SessionScreen(ex: ex), assets: ['assets/scenes/march.jpg']));
  testWidgets('celebrate', (t) => _shot(t, 'celebrate', const CelebrationScreen(ex: ex, reward: Reward(paws: 10, bonus: 0, doneNow: 1)), assets: ['assets/scenes/celebrate.jpg']));
}
