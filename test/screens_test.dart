import 'dart:io';

import 'package:bloom/app/shell.dart';
import 'package:bloom/app/theme.dart';
import 'package:bloom/data/exercises.dart';
import 'package:bloom/data/today.dart';
import 'dart:convert';

import 'package:bloom/features/plan/plan_screen.dart';
import 'package:bloom/features/profile/plan_report_screen.dart';
import 'package:bloom/features/profile/profile_screen.dart';
import 'package:bloom/features/profile/weekly_screen.dart';
import 'package:bloom/features/profile/weight_history_screen.dart';
import 'package:bloom/features/progress/progress_screen.dart';
import 'package:bloom/features/shop/shop_screen.dart';
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

Future<void> _shot(WidgetTester tester, String name, Widget home, {List<String> assets = const [], Future<void> Function(WidgetTester)? then, Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  SharedPreferences.setMockInitialValues(prefs);
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
  if (then != null) {
    await then(tester);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
}

/// Sixteen days into the journey, with weigh-ins and a few active days.
Map<String, Object> _seed() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 16));
  final days = <String, Object>{};
  for (var i = 0; i <= 16; i++) {
    final d = start.add(Duration(days: i));
    final moves = [2, 3, 1, 0, 3, 2, 1][i % 7];
    days[dayKey(d)] = {'m': moves, 's': moves * 140, 'k': i.isEven ? ['m1', 's1', 's2'] : ['m1', 'm2'], 'r': 6};
  }
  final kg = [92.0, 91.6, 91.7, 91.1, 90.8, 90.2, 89.9];
  return {
    'bloom.journal.v1': jsonEncode({'start': dayKey(start), 'effort': 34.0, 'days': days}),
    'bloom.weight.v1': jsonEncode({
      'entries': [for (var i = 0; i < kg.length; i++) {'at': start.add(Duration(days: i * 16 ~/ 6, hours: 8)).toIso8601String(), 'kg': kg[i]}],
      'goalKg': 82.0,
    }),
    'bloom.profile.v1': jsonEncode({'name': 'Sam'}),
  };
}

void main() {
  setUpAll(_fonts);
  const ex = Exercise(id: 'march', name: 'March in place', seconds: 120, effort: 1, cues: ['Knees up! Like this!']);
  testWidgets('today', (t) => _shot(t, 'today', const Shell(), assets: ['assets/scenes/living.jpg']));
  testWidgets('ready', (t) => _shot(t, 'ready', const ReadyScreen(ex: ex), assets: ['assets/scenes/ready.jpg']));
  testWidgets('session', (t) => _shot(t, 'session', const SessionScreen(ex: ex), assets: ['assets/scenes/march.jpg']));
  testWidgets('celebrate', (t) => _shot(t, 'celebrate', const CelebrationScreen(ex: ex, reward: Reward(paws: 10, bonus: 0, doneNow: 1)), assets: ['assets/scenes/celebrate.jpg']));
  testWidgets('shop', (t) => _shot(t, 'shop', const Scaffold(body: ShopScreen()), assets: ['assets/scenes/garage.jpg']));
  testWidgets('plan', (t) => _shot(t, 'plan', const Scaffold(body: PlanScreen()), assets: ['assets/scenes/balcony.jpg'], then: (t) async {
        await t.tap(find.bySemanticsLabel('Morning walk'));
        await t.tap(find.bySemanticsLabel('Fast food'));
      }));
  testWidgets('plan-sheet', (t) => _shot(t, 'plan-sheet', const Scaffold(body: PlanScreen()), assets: ['assets/scenes/balcony.jpg'], then: (t) async {
        await t.scrollUntilVisible(find.text('Add a rule'), 200, scrollable: find.byType(Scrollable).first);
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.text('Add a rule'));
      }));
  testWidgets('progress-empty', (t) => _shot(t, 'progress-empty', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/hallway.jpg']));
  testWidgets('progress', (t) => _shot(t, 'progress', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/hallway.jpg'], prefs: _seed()));
  testWidgets('progress-journey', (t) => _shot(t, 'progress-journey', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/hallway.jpg'], prefs: _seed(), then: (t) async {
        await t.tap(find.text('Her journey'));
        await t.pump(const Duration(milliseconds: 400));
        await t.drag(find.byType(Scrollable).first, const Offset(0, -420));
      }));
  testWidgets('log-weight', (t) => _shot(t, 'log-weight', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/hallway.jpg'], prefs: _seed(), then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.text('Log weight'));
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.tap(find.bySemanticsLabel('Decrease today’s weight'));
        await t.tap(find.bySemanticsLabel('Decrease today’s weight'));
      }));
  testWidgets('profile', (t) => _shot(t, 'profile', const Scaffold(body: ProfileScreen()), assets: ['assets/scenes/bedroom.jpg'], prefs: _seed()));
  testWidgets('profile-scrolled', (t) => _shot(t, 'profile-scrolled', const Scaffold(body: ProfileScreen()), assets: ['assets/scenes/bedroom.jpg'], prefs: _seed(), then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      }));
  testWidgets('weekly', (t) => _shot(t, 'weekly', const WeeklyScreen(), prefs: _seed()));
  testWidgets('weight-history', (t) => _shot(t, 'weight-history', const WeightHistoryScreen(), prefs: _seed()));
  testWidgets('plan-report', (t) => _shot(t, 'plan-report', const PlanReportScreen(), prefs: _seed()));
}
