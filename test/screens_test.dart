import 'dart:io';

import 'package:bloom/app/clock.dart';
import 'package:bloom/app/shell.dart';
import 'package:bloom/app/theme.dart';
import 'package:bloom/data/exercises.dart';
import 'package:bloom/data/journal.dart';
import 'package:bloom/data/today.dart';
import 'dart:convert';

import 'package:bloom/features/food/food_check_screen.dart';
import 'package:bloom/features/onboarding/onboarding_flow.dart';
import 'package:bloom/features/paywall/paywall_screen.dart';
import 'package:bloom/features/plan/plan_screen.dart';
import 'package:bloom/features/profile/plan_report_screen.dart';
import 'package:bloom/features/profile/profile_screen.dart';
import 'package:bloom/features/profile/weekly_screen.dart';
import 'package:bloom/features/profile/weight_history_screen.dart';
import 'package:bloom/features/progress/progress_screen.dart';
import 'package:bloom/features/shop/shop_screen.dart';
import 'package:bloom/features/today/celebration_screen.dart';
import 'package:bloom/features/urge/urge_screen.dart';
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

Future<void> _shot(WidgetTester tester, String name, Widget home, {List<String> assets = const [], Future<void> Function(WidgetTester)? then, Map<String, Object> prefs = const {}, int hour = 10}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  SharedPreferences.setMockInitialValues(prefs);
  final now = DateTime.now();
  final pinned = DateTime(now.year, now.month, now.day, hour, 40);
  await tester.pumpWidget(ProviderScope(
    overrides: [clockProvider.overrideWithValue(() => pinned)],
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
    days[dayKey(d)] = {'m': moves, 's': moves * 140, 'k': i.isEven ? ['m1', 's1', 's2'] : ['m1', 'm2'], 'r': 6, if (i % 3 != 0 && i < 16) 'c': ['all', 'mostly'][i % 2]};
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

/// Today's plan with two rules kept, for the check-in.
Map<String, Object> _evening({String? answer}) {
  final seed = _seed();
  final today = dayKey(DateTime.now());
  seed['bloom.plan.v1'] = jsonEncode({
    'day': today,
    'kept': ['m1', 's2'],
    'rules': [
      {'id': 'm1', 'kind': 'more', 'title': 'Morning walk', 'icon': 'walk'},
      {'id': 'm2', 'kind': 'more', 'title': 'Drink water first', 'icon': 'water'},
      {'id': 's1', 'kind': 'skip', 'title': 'Sugary drinks', 'icon': 'drink'},
      {'id': 's2', 'kind': 'skip', 'title': 'Fast food', 'icon': 'fastfood'},
    ],
  });
  if (answer != null) {
    final j = jsonDecode(seed['bloom.journal.v1']! as String) as Map<String, dynamic>;
    (j['days'] as Map<String, dynamic>)[today] = {'m': 1, 's': 120, 'k': ['m1', 's2'], 'r': 4, 'c': answer};
    seed['bloom.journal.v1'] = jsonEncode(j);
  }
  return seed;
}

void main() {
  setUpAll(_fonts);
  const ex = Exercise(id: 'march', name: 'March in place', seconds: 120, effort: 1, cues: ['Knees up! Like this!']);
  testWidgets('today', (t) => _shot(t, 'today', const Shell(), assets: ['assets/scenes/living.jpg']));
  testWidgets('ready', (t) => _shot(t, 'ready', const ReadyScreen(ex: ex), assets: ['assets/scenes/ready-empty.jpg']));
  testWidgets('session', (t) => _shot(t, 'session', const SessionScreen(ex: ex), assets: ['assets/scenes/march-empty.jpg']));
  testWidgets('celebrate', (t) => _shot(t, 'celebrate', const CelebrationScreen(ex: ex, reward: Reward(paws: 10, bonus: 0, doneNow: 1, flag: Milestone(7, 'First week', ''))), assets: ['assets/scenes/celebrate-empty.jpg']));
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

  // Onboarding: walk the flow by tapping, then shoot the step reached.
  const obAssets = ['assets/scenes/porch.jpg', 'assets/scenes/living.jpg', 'assets/scenes/hallway.jpg', 'assets/scenes/gift.jpg'];
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester t, String s) async {
    await t.ensureVisible(find.text(s).last);
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text(s).last);
    await settle(t);
  }

  Future<void> toName(WidgetTester t) async {
    await tapText(t, 'Let’s meet her');
    await t.enterText(find.byType(TextField), 'Sam');
    await settle(t);
  }

  Future<void> toNumbers(WidgetTester t) async {
    await toName(t);
    await tapText(t, 'Next');
    await tapText(t, 'Move more every day');
    await tapText(t, 'Next');
  }

  Future<void> toLimits(WidgetTester t) async {
    await toNumbers(t);
    await tapText(t, 'Next');
    await tapText(t, 'Next');
    await tapText(t, 'Mostly sitting');
    await tapText(t, 'Next');
    await tapText(t, 'Back');
    await tapText(t, 'Knees');
  }

  Future<void> toJourney(WidgetTester t) async {
    await toLimits(t);
    await tapText(t, 'Next');
    await tapText(t, 'Maybe later');
  }

  testWidgets('ob-welcome', (t) => _shot(t, 'ob-welcome', const OnboardingFlow(), assets: obAssets));
  testWidgets('ob-name', (t) => _shot(t, 'ob-name', const OnboardingFlow(), assets: obAssets, then: toName));
  testWidgets('ob-numbers', (t) => _shot(t, 'ob-numbers', const OnboardingFlow(), assets: obAssets, then: toNumbers));
  testWidgets('ob-pace', (t) => _shot(t, 'ob-pace', const OnboardingFlow(), assets: obAssets, then: (t) async {
        await toNumbers(t);
        await tapText(t, 'Next');
      }));
  testWidgets('ob-limits', (t) => _shot(t, 'ob-limits', const OnboardingFlow(), assets: obAssets, then: toLimits));
  testWidgets('ob-reminders', (t) => _shot(t, 'ob-reminders', const OnboardingFlow(), assets: obAssets, then: (t) async {
        await toLimits(t);
        await tapText(t, 'Next');
      }));
  testWidgets('ob-journey', (t) => _shot(t, 'ob-journey', const OnboardingFlow(), assets: obAssets, then: toJourney));
  testWidgets('paywall', (t) => _shot(t, 'paywall', Scaffold(body: PaywallScreen(onDone: () {})), assets: obAssets));

  testWidgets('check-in', (t) => _shot(t, 'check-in', const Shell(), assets: ['assets/scenes/living.jpg'], prefs: _evening(), hour: 20));
  testWidgets('check-in-picked', (t) => _shot(t, 'check-in-picked', const Shell(), assets: ['assets/scenes/living.jpg'], prefs: _evening(), hour: 20, then: (t) async {
        await t.tap(find.text('Stuck to it'));
        await t.pump(const Duration(milliseconds: 200));
        await t.tap(find.text('Drink water first').last);
      }));
  testWidgets('today-checked-in', (t) => _shot(t, 'today-checked-in', const Shell(), assets: ['assets/scenes/living.jpg'], prefs: _evening(answer: 'mostly'), hour: 20));
  testWidgets('today-missed', (t) {
    final start = DateTime.now().subtract(const Duration(days: 3));
    return _shot(t, 'today-missed', const Shell(), assets: ['assets/scenes/living-empty.jpg'], prefs: {
      'bloom.journal.v1': jsonEncode({'start': dayKey(start), 'effort': 4.0, 'days': {}}),
    });
  });
  testWidgets('urge', (t) => _shot(t, 'urge', const UrgeScreen(), assets: ['assets/scenes/ready-empty.jpg']));
  testWidgets('urge-breathe', (t) => _shot(t, 'urge-breathe', const UrgeScreen(), assets: ['assets/scenes/ready-empty.jpg'], then: (t) async {
        await t.tap(find.text('Breathe with me'));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }));
  testWidgets('urge-ask', (t) => _shot(t, 'urge-ask', const UrgeScreen(), assets: ['assets/scenes/ready-empty.jpg'], then: (t) async {
        await t.tap(find.text('Drink a glass of water'));
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.text('Done'));
      }));
  testWidgets('today-dusk', (t) => _shot(t, 'today-dusk', const Shell(), assets: ['assets/scenes/living.jpg'], prefs: _evening(answer: 'all'), hour: 19));
  testWidgets('today-night', (t) => _shot(t, 'today-night', const Shell(), assets: ['assets/scenes/living.jpg'], prefs: _evening(answer: 'mostly'), hour: 23));
  testWidgets('today-dawn', (t) => _shot(t, 'today-dawn', const Shell(), assets: ['assets/scenes/living.jpg'], hour: 6));
  testWidgets('food', (t) => _shot(t, 'food', const FoodCheckScreen()));
  testWidgets('food-example', (t) => _shot(t, 'food-example', const FoodCheckScreen(), then: (t) async {
        await t.tap(find.text('See an example'));
      }));
}
