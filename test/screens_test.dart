import 'dart:io';

import 'package:bloom/app/clock.dart';
import 'package:clock/clock.dart';
import 'package:bloom/app/shell.dart';
import 'package:bloom/app/theme.dart';
import 'package:bloom/features/lab/move_lab_screen.dart';
import 'package:bloom/features/streak/streak_screens.dart';
import 'package:bloom/ui/clover_rive.dart';
import 'package:bloom/data/exercises.dart';
import 'package:bloom/data/journal.dart';
import 'package:bloom/data/today.dart';
import 'dart:convert';

import 'package:bloom/features/alarm/alarms_screen.dart';
import 'package:bloom/data/borrowed.dart';
import 'package:bloom/data/premium.dart';
import 'package:bloom/features/alarm/ringing_screen.dart';
import 'package:bloom/features/food/food_check_screen.dart';
import 'package:bloom/features/onboarding/onboarding_flow.dart';
import 'package:bloom/features/paywall/paywall_screen.dart';
import 'package:bloom/features/plan/plan_screen.dart';
import 'package:bloom/features/profile/cat_picker.dart';
import 'package:bloom/features/profile/plan_report_screen.dart';
import 'package:bloom/features/profile/profile_screen.dart';
import 'package:bloom/features/profile/settings_screen.dart';
import 'package:bloom/features/profile/subscription_screen.dart';
import 'package:bloom/features/profile/weekly_screen.dart';
import 'package:bloom/features/profile/weight_history_screen.dart';
import 'package:bloom/features/profile/widget_sheet.dart';
import 'package:bloom/features/progress/progress_screen.dart';
import 'package:bloom/features/shop/shop_screen.dart';
import 'package:bloom/features/today/celebration_screen.dart';
import 'package:bloom/features/urge/urge_screen.dart';
import 'package:bloom/features/today/ready_screen.dart';
import 'package:bloom/features/today/session_screen.dart';
import 'package:bloom/features/today/exercise_picker.dart';
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

/// The day every shot is taken on (the goldens were made then).
final _now = DateTime(2026, 10, 22, 10, 40);

Future<void> _shot(WidgetTester tester, String name, Widget home, {List<String> assets = const [], Future<void> Function(WidgetTester)? then, Map<String, Object> prefs = const {}, int hour = 10}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  SharedPreferences.setMockInitialValues(prefs);
  FxLayer.debugSeed = 7;
  final pinned = DateTime(_now.year, _now.month, _now.day, hour, 40);
  // Everything the app reads from the clock, in widgets or not, sees the pinned day, so shots don't drift by date.
  await withClock(Clock.fixed(pinned), () => _capture(tester, name, home, pinned, assets: assets, then: then));
}

Future<void> _capture(WidgetTester tester, String name, Widget home, DateTime pinned, {required List<String> assets, Future<void> Function(WidgetTester)? then}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [clockProvider.overrideWithValue(() => pinned)],
    child: MaterialApp(theme: bloomTheme(), debugShowCheckedModeBanner: false, builder: (c, child) => FxLayer.wrap(child!), home: home),
  ));
  await tester.runAsync(() async {
    for (final a in [CloverStill.asset, ..._iconArt, ...assets]) {
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
  final now = _now;
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 16));
  final days = <String, Object>{};
  for (var i = 0; i <= 16; i++) {
    final d = start.add(Duration(days: i));
    final moves = [2, 3, 1, 0, 3, 2, 1][i % 7];
    days[dayKey(d)] = {
      'm': moves,
      's': moves * 140,
      'k': i.isEven ? ['m1', 's1', 's2'] : ['m1', 'm2'],
      'r': 6,
      if (i % 3 != 0 && i < 16) 'c': ['all', 'mostly'][i % 2],
      // How often water and "no sugary drinks" were logged.
      'n': {'m1': [6, 8, 5, 3, 7, 8, 4][i % 7], if (i.isEven) 's1': [1, 2, 3, 1][i % 4]},
    };
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
  final today = dayKey(_now);
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

/// Every Shop item's picture, so the Shop shots don't catch them still decoding.
final _shopArt = [for (final f in Directory('assets/shop').listSync()) f.path];
final _planArt = [for (final f in Directory('assets/plan').listSync()) f.path];
// The painted icons show on most screens: every shot loads them.
final _iconArt = [for (final f in Directory('assets/icons').listSync()) f.path];

void main() {
  setUpAll(_fonts);
  const ex = Exercise(id: 'march', name: 'March in place', seconds: 120, effort: 1, cues: ['Knees up! Like this!']);
  testWidgets('today', (t) => _shot(t, 'today', const Shell(), assets: ['assets/scenes/living.jpg']));
  // Swiped up, the living room tucks away (as in the other rooms): the slim title, the craving button and the paws stay.
  testWidgets('today-scrolled', (t) => _shot(t, 'today-scrolled', const Shell(), assets: ['assets/scenes/living.jpg'], then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await t.pump(const Duration(milliseconds: 600));
      }));
  testWidgets('ready', (t) => _shot(t, 'ready', const ReadyScreen(ex: ex), assets: ['assets/scenes/ready-empty.jpg']));
  testWidgets('exercise-picker', (t) => _shot(t, 'exercise-picker', Scaffold(body: Consumer(builder: (c, ref, _) => Center(child: TextButton(onPressed: () => showExercisePicker(c, ref), child: const Text('open'))))), then: (t) async {
        await t.tap(find.text('open'));
      }));
  testWidgets('session', (t) => _shot(t, 'session', const SessionScreen(ex: ex), assets: ['assets/scenes/march-empty.jpg']));
  // Calf raises have a room of their own now: at the kitchen counter (after the 3-2-1).
  testWidgets('session-calf', (t) => _shot(t, 'session-calf', SessionScreen(ex: exerciseById('calf_raises')!), assets: ['assets/scenes/craving-kitchen.jpg'], then: (t) async {
        for (var i = 0; i < 40; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }));
  // Streak: the seed misses day 10 (patched here) and day 3, so the run is 13 days.
  Map<String, Object> streakSeed() {
    final now = _now;
    final missed = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    return {..._seed(), 'bloom.streak.v1': jsonEncode({'p': 1, 'pd': [dayKey(missed)], 'l': 13})};
  }
  testWidgets('streak', (t) => _shot(t, 'streak', const StreakScreen(), prefs: streakSeed()));
  testWidgets('streak calendar swipes between months, even in the first month', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    // A journey that began today: there's still a year of months to swipe back through.
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(ProviderScope(child: MaterialApp(theme: bloomTheme(), home: const StreakScreen())));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final now = _now;
    String title(DateTime m) => '${names[m.month - 1]} ${m.year}';
    final prev = DateTime(now.year, now.month - 1);
    await t.ensureVisible(find.byType(PageView));
    await t.pumpAndSettle();
    expect(find.text(title(now)), findsOneWidget);
    // A slow drag that follows the finger, then lets go past halfway.
    await t.drag(find.byType(PageView), const Offset(260, 0));
    await t.pumpAndSettle();
    expect(find.text(title(prev)), findsOneWidget);
    await t.drag(find.byType(PageView), const Offset(-260, 0));
    await t.pumpAndSettle();
    expect(find.text(title(now)), findsOneWidget);
    // Nothing after this month.
    await t.drag(find.byType(PageView), const Offset(-260, 0));
    await t.pumpAndSettle();
    expect(find.text(title(now)), findsOneWidget);
  });
  testWidgets('streak-celebrate', (t) => _shot(t, 'streak-celebrate', const StreakCelebrationScreen(reward: Reward(paws: 10, bonus: 0, doneNow: 1)), assets: ['assets/scenes/celebrate-empty.jpg'], prefs: streakSeed()));
  testWidgets('streak-patch', (t) {
    final now = _now;
    final from = dayKey(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)));
    return _shot(t, 'streak-patch', StreakPatchScreen(gap: (from: from, days: 1, run: 13)), prefs: streakSeed());
  });
  testWidgets('move-lab', (t) => _shot(t, 'move-lab', const MoveLabScreen()));
  testWidgets('preview session saves nothing', (t) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: bloomTheme(), builder: (c, child) => FxLayer.wrap(child!), home: const Scaffold(body: Text('lab'))),
    ));
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const SessionScreen(ex: ex, preview: true)));
    await t.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    // Let the saved state finish loading (a first run grants its welcome paws) before taking the baseline.
    for (var i = 0; i < 50 && !container.read(todayProvider).loaded; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
    }
    expect(container.read(todayProvider).loaded, isTrue);
    final before = container.read(todayProvider);
    await t.tap(find.text('Skip to the end'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('lab'), findsOneWidget);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    expect(container.read(todayProvider).doneIds, before.doneIds);
    expect(container.read(todayProvider).paws, before.paws);
  });
  testWidgets('celebrate', (t) => _shot(t, 'celebrate', const CelebrationScreen(ex: ex, reward: Reward(paws: 10, bonus: 0, doneNow: 1, flag: Milestone(7, 'First week', ''))), assets: ['assets/scenes/celebrate-empty.jpg']));
  testWidgets('shop', (t) => _shot(t, 'shop', const Scaffold(body: ShopScreen()), assets: ['assets/scenes/garage.jpg', ..._shopArt]));
  testWidgets('shop-outfits', (t) => _shot(t, 'shop-outfits', const Scaffold(body: ShopScreen()), assets: ['assets/scenes/garage.jpg', ..._shopArt], prefs: {
        'bloom.today.v2': jsonEncode({'paws': 140, 'owned': ['mat', 'o_sweatband', 'o_glasses'], 'worn': {'head': 'o_sweatband'}}),
      }, then: (t) async {
        await t.tap(find.text('Outfits'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(find.text('Head').first);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.scrollUntilVisible(find.text('Flower crown'), 200, scrollable: find.byType(Scrollable).last);
      }));
  testWidgets('shop-docked', (t) => _shot(t, 'shop-docked', const Scaffold(body: ShopScreen()), assets: ['assets/scenes/garage.jpg', ..._shopArt], then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      }));
  testWidgets('plan-docked', (t) => _shot(t, 'plan-docked', const Scaffold(body: PlanScreen()), assets: ['assets/scenes/balcony.jpg', ..._planArt], then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      }));
  testWidgets('shop-decor', (t) => _shot(t, 'shop-decor', const Scaffold(body: ShopScreen()), assets: ['assets/scenes/garage.jpg', ..._shopArt], then: (t) async {
        await t.tap(find.text('Room decor'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.scrollUntilVisible(find.text('Record player'), 200, scrollable: find.byType(Scrollable).last);
      }));
  testWidgets('plan', (t) => _shot(t, 'plan', const Scaffold(body: PlanScreen()), assets: ['assets/scenes/balcony.jpg', ..._planArt], then: (t) async {
        await t.tap(find.bySemanticsLabel(RegExp('^Log Drink water')));
        await t.pump(const Duration(milliseconds: 900));
        await t.tap(find.bySemanticsLabel('Morning walk'));
        await t.pump(const Duration(seconds: 4));
        await t.pump(const Duration(seconds: 1));
      }));
  testWidgets('cat-picker', (t) => _shot(t, 'cat-picker', Scaffold(body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => showCatPicker(c), child: const Text('open'))))), assets: ['assets/cats/thumb-clover.png', 'assets/cats/thumb-fold.png', 'assets/cats/thumb-calico.png'], then: (t) async {
        await t.tap(find.text('open'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.text('Mochi'));
      }));
  // For the deck: Habits mid-day, two kept, nothing popping up.
  testWidgets('deck-habits', (t) {
    final ms = _now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch;
    return _shot(t, 'deck-habits', const Scaffold(body: PlanScreen()), assets: ['assets/scenes/balcony.jpg', ..._planArt], prefs: {
      'bloom.plan.v2': jsonEncode({
        'day': dayKey(_now),
        'logs': {'m1': [ms, ms + 1000, ms + 2000, ms + 3000, ms + 4000], 'm2': [ms]},
        'rules': [
          {'id': 'm1', 'kind': 'more', 'title': 'Drink water', 'icon': 'water', 'goal': 8},
          {'id': 'm2', 'kind': 'more', 'title': 'Morning walk', 'icon': 'walk'},
          {'id': 'm3', 'kind': 'more', 'title': '10-minute stretch', 'icon': 'stretch'},
          {'id': 's1', 'kind': 'skip', 'title': 'Sugary drinks', 'icon': 'drink', 'goal': 3},
          {'id': 's2', 'kind': 'skip', 'title': 'Late-night snacks', 'icon': 'snack'},
        ],
      }),
    });
  });
  testWidgets('plan-edit', (t) => _shot(t, 'plan-edit', const Scaffold(body: PlanScreen()), assets: ['assets/scenes/balcony.jpg', ..._planArt], then: (t) async {
        await t.tap(find.text('Morning walk'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
      }));
  // Habits is one list: the ones to avoid sit below the ones to do.
  testWidgets('plan-donts', (t) => _shot(t, 'plan-donts', const Scaffold(body: PlanScreen()), assets: ['assets/scenes/balcony.jpg', ..._planArt], then: (t) async {
        await t.scrollUntilVisible(find.text('Add one to avoid'), 200, scrollable: find.byType(Scrollable).first);
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.bySemanticsLabel(RegExp('^Said no to Sugary drinks')));
        await t.pump(const Duration(seconds: 4));
        await t.pump(const Duration(seconds: 1));
      }));
  testWidgets('plan-sheet', (t) => _shot(t, 'plan-sheet', const Scaffold(body: PlanScreen()), assets: ['assets/scenes/balcony.jpg', ..._planArt], then: (t) async {
        await t.scrollUntilVisible(find.text('Add a habit to do'), 200, scrollable: find.byType(Scrollable).first);
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.text('Add a habit to do'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.text('A few times'));
      }));
  testWidgets('progress-empty', (t) => _shot(t, 'progress-empty', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg']));
  testWidgets('progress', (t) => _shot(t, 'progress', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg'], prefs: _seed()));
  // Swiped up, the stairs tuck away and the Journey/Weight switch docks under the slim title.
  testWidgets('progress-scrolled', (t) => _shot(t, 'progress-scrolled', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg'], prefs: _seed(), then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await t.pump(const Duration(milliseconds: 600));
      }));
  testWidgets('progress-together', (t) => _shot(t, 'progress-together', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg', for (var i = 1; i <= 5; i++) 'assets/scenes/portrait-$i.webp'], prefs: _seed(), then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -420));
      }));
  testWidgets('progress-day', (t) => _shot(t, 'progress-day', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg', for (var i = 1; i <= 5; i++) 'assets/scenes/portrait-$i.webp'], prefs: _seed(), then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -420));
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(find.bySemanticsLabel(RegExp(r'^(Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day ')).at(4));
      }));
  testWidgets('progress-noweight', (t) => _shot(t, 'progress-noweight', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg', ..._planArt], prefs: {
        ..._seed(),
        'bloom.plan.v2': jsonEncode({
          'day': dayKey(_now),
          'logs': {},
          'rules': [
            {'id': 'm1', 'kind': 'more', 'title': 'Drink water', 'icon': 'water', 'goal': 8},
            {'id': 'm2', 'kind': 'more', 'title': 'Morning walk', 'icon': 'walk'},
            {'id': 'm3', 'kind': 'more', 'title': '10-minute stretch', 'icon': 'stretch'},
            {'id': 'm4', 'kind': 'more', 'title': 'Take the stairs', 'icon': 'stairs', 'goal': 4},
            {'id': 'm5', 'kind': 'more', 'title': 'Vegetables with lunch', 'icon': 'veg'},
            {'id': 's1', 'kind': 'skip', 'title': 'Sugary drinks', 'icon': 'drink', 'goal': 3},
            {'id': 's2', 'kind': 'skip', 'title': 'Fast food', 'icon': 'fastfood'},
          ],
        }),
      }, then: (t) async {
        // Without weight tracked, Progress is one page: the journey and the reports.
        await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      }));
  testWidgets('progress-weight', (t) => _shot(t, 'progress-weight', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg'], prefs: _seed(), then: (t) async {
        await t.tap(find.text('Weight'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.drag(find.byType(Scrollable).first, const Offset(0, -420));
      }));
  testWidgets('progress-portrait', (t) => _shot(t, 'progress-portrait', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg', for (var i = 1; i <= 5; i++) 'assets/scenes/portrait-$i.webp'], prefs: _seed(), then: (t) async {
        await t.tapAt(const Offset(80, 130));
        await t.pump();
      }));
  testWidgets('log-weight', (t) => _shot(t, 'log-weight', const Scaffold(body: ProgressScreen()), assets: ['assets/scenes/stairs-day.jpg'], prefs: _seed(), then: (t) async {
        await t.tap(find.text('Weight'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.scrollUntilVisible(find.text('Log today’s weight'), 200, scrollable: find.byType(Scrollable).first);
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.text('Log today’s weight'));
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.tap(find.bySemanticsLabel('Decrease today’s weight'));
        await t.tap(find.bySemanticsLabel('Decrease today’s weight'));
      }));
  testWidgets('profile', (t) => _shot(t, 'profile', const Scaffold(body: ProfileScreen()), assets: ['assets/scenes/bedroom-empty.jpg', 'assets/cats/avatar-clover.png'], prefs: _seed()));
  testWidgets('settings', (t) => _shot(t, 'settings', const SettingsScreen(), prefs: _seed()));
  // Membership, for testing both plans: free with the way to Plus; Plus (a test purchase) with cancelling.
  testWidgets('subscription-free', (t) => _shot(t, 'subscription-free', const SubscriptionScreen(), prefs: _seed()));
  testWidgets('subscription-plus', (t) => _shot(t, 'subscription-plus', const SubscriptionScreen(),
      prefs: {..._seed(), 'bloom.premium.v1': '{"active":true,"plan":"yearly","trialEnds":"2026-10-28T10:00:00.000","test":true}'}));
  // Borrowing test paws lands them in the balance; giving back takes them out again; cancelling Plus goes free.
  testWidgets('borrow-paws-and-cancel', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    SharedPreferences.setMockInitialValues({..._seed(), 'bloom.premium.v1': '{"active":true,"plan":"monthly","test":true}'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(theme: bloomTheme(), home: const SettingsScreen())));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final before = container.read(todayProvider).paws;
    await t.scrollUntilVisible(find.text('Give borrowed paws back'), 300, scrollable: find.byType(Scrollable).first);
    await t.pump();
    await t.tap(find.text('+1,000'));
    await t.tap(find.text('+1,000'));
    await t.pump();
    expect(container.read(todayProvider).paws, before + 2000);
    expect(container.read(borrowedProvider), 2000);
    await t.tap(find.text('Give borrowed paws back'));
    await t.pump();
    expect(container.read(todayProvider).paws, before);
    expect(container.read(borrowedProvider), 0);
    expect(container.read(premiumProvider).active, isTrue);
    await container.read(premiumProvider.notifier).cancel();
    expect(container.read(premiumProvider).active, isFalse);
  });
  testWidgets('profile-scrolled', (t) => _shot(t, 'profile-scrolled', const Scaffold(body: ProfileScreen()), assets: ['assets/scenes/bedroom-empty.jpg', 'assets/cats/avatar-clover.png'], prefs: _seed(), then: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      }));
  testWidgets('weekly', (t) => _shot(t, 'weekly', const WeeklyScreen(), prefs: _seed()));
  testWidgets('weight-history', (t) => _shot(t, 'weight-history', const WeightHistoryScreen(), prefs: _seed()));
  testWidgets('plan-report', (t) => _shot(t, 'plan-report', const PlanReportScreen(), assets: _planArt, prefs: _seed()));

  // Onboarding: walk the flow by tapping, then shoot the step reached.
  final obAssets = ['assets/scenes/porch.jpg', 'assets/scenes/ready-empty.jpg', 'assets/scenes/living-empty.jpg', 'assets/scenes/balcony-empty.jpg', 'assets/scenes/march-empty.jpg', 'assets/scenes/garage-empty.jpg', 'assets/scenes/bedroom-empty.jpg', 'assets/scenes/stairs-day.jpg', 'assets/scenes/celebrate-empty.jpg', 'assets/scenes/gift.jpg', 'assets/cats/thumb-clover.png', 'assets/scenes/bedroom-window.png', 'assets/scenes/sky-cloud-a.png', 'assets/scenes/sky-cloud-b.png', 'assets/scenes/sky-cloud-c.png', ..._planArt];
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester t, String s) async {
    await t.ensureVisible(find.text(s).last);
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text(s).last, warnIfMissed: false);
    await settle(t);
  }

  Future<void> toCat(WidgetTester t) => tapText(t, 'Let’s meet her');
  Future<void> toName(WidgetTester t) async {
    await toCat(t);
    await tapText(t, 'That’s her name');
    await t.enterText(find.byType(TextField).last, 'Sam');
    await settle(t);
  }

  Future<void> toWhy(WidgetTester t) async {
    await toName(t);
    await tapText(t, 'Nice to meet you');
  }

  Future<void> toNumbers(WidgetTester t) async {
    await toWhy(t);
    await tapText(t, 'Move more every day');
    await tapText(t, 'That’s me');
  }

  Future<void> toPace(WidgetTester t) async {
    await toNumbers(t);
    await tapText(t, 'Next');
  }

  Future<void> toBody(WidgetTester t) async {
    await toPace(t);
    await tapText(t, 'Steady it is');
    await tapText(t, 'Some walking');
    await tapText(t, 'Knees');
  }

  Future<void> toReminders(WidgetTester t) async {
    await toBody(t);
    await tapText(t, 'Next');
  }

  Future<void> toBuilding(WidgetTester t) async {
    await toReminders(t);
    await tapText(t, 'Maybe later');
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> toJourney(WidgetTester t) async {
    await toBuilding(t);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('ob-welcome', (t) => _shot(t, 'ob-welcome', const OnboardingFlow(), assets: obAssets));
  testWidgets('ob-cat-name', (t) => _shot(t, 'ob-cat-name', const OnboardingFlow(), assets: obAssets, then: toCat));
  testWidgets('ob-name', (t) => _shot(t, 'ob-name', const OnboardingFlow(), assets: obAssets, then: toName));
  testWidgets('ob-why', (t) => _shot(t, 'ob-why', const OnboardingFlow(), assets: obAssets, then: (t) async {
        await toWhy(t);
        await tapText(t, 'Move more every day');
      }));
  testWidgets('ob-numbers', (t) => _shot(t, 'ob-numbers', const OnboardingFlow(), assets: obAssets, then: toNumbers));
  testWidgets('ob-pace', (t) => _shot(t, 'ob-pace', const OnboardingFlow(), assets: obAssets, then: toPace));
  testWidgets('ob-body', (t) => _shot(t, 'ob-body', const OnboardingFlow(), assets: obAssets, then: toBody));
  testWidgets('ob-reminders', (t) => _shot(t, 'ob-reminders', const OnboardingFlow(), assets: obAssets, then: toReminders));
  testWidgets('ob-building', (t) => _shot(t, 'ob-building', const OnboardingFlow(), assets: obAssets, then: toBuilding));
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
    final start = _now.subtract(const Duration(days: 3));
    return _shot(t, 'today-missed', const Shell(), assets: ['assets/scenes/living-empty.jpg'], prefs: {
      'bloom.journal.v1': jsonEncode({'start': dayKey(start), 'effort': 4.0, 'days': {}}),
    });
  });
  const urgeArt = ['assets/urge/water.webp', 'assets/urge/breathe.webp', 'assets/urge/walk.webp', 'assets/urge/room.webp'];
  testWidgets('urge', (t) => _shot(t, 'urge', const UrgeScreen(), assets: ['assets/scenes/craving-sea.jpg', ...urgeArt]));
  // Each quiet task has a room of its own: water in her kitchen, a breath in her window nook.
  testWidgets('urge-water', (t) => _shot(t, 'urge-water', const UrgeScreen(), assets: ['assets/scenes/craving-sea.jpg', 'assets/scenes/craving-kitchen.jpg', ...urgeArt], then: (t) async {
        await t.tap(find.text('Drink a glass of water'));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }));
  testWidgets('urge-walk', (t) => _shot(t, 'urge-walk', const UrgeScreen(), assets: ['assets/scenes/craving-sea.jpg', 'assets/scenes/craving-lane.jpg', ...urgeArt], then: (t) async {
        await t.tap(find.text('A short walk'));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }));
  testWidgets('urge-room', (t) => _shot(t, 'urge-room', const UrgeScreen(), assets: ['assets/scenes/craving-sea.jpg', 'assets/scenes/craving-window.jpg', ...urgeArt], then: (t) async {
        await t.tap(find.text('Change rooms'));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }));
  testWidgets('urge-breathe', (t) => _shot(t, 'urge-breathe', const UrgeScreen(), assets: ['assets/scenes/craving-sea.jpg', 'assets/scenes/craving-nook.jpg', ...urgeArt], then: (t) async {
        await t.tap(find.text('Breathe with me'));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }));
  testWidgets('urge-ask', (t) => _shot(t, 'urge-ask', const UrgeScreen(), assets: ['assets/scenes/craving-sea.jpg', 'assets/scenes/craving-kitchen.jpg', ...urgeArt], then: (t) async {
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
  testWidgets('widget-sheet', (t) => _shot(t, 'widget-sheet', const Scaffold(body: Padding(padding: EdgeInsets.fromLTRB(20, 80, 20, 0), child: WidgetSheet())), assets: ['assets/widget/widget_clover_rest.png']));
  final alarms = {'bloom.alarms.v1': jsonEncode([
    {'id': 1, 'hour': 7, 'minute': 0, 'days': [1, 2, 3, 4, 5], 'label': 'Work days', 'tune': 'morningPurr', 'vibrate': true, 'gentle': true, 'enabled': true},
    {'id': 2, 'hour': 9, 'minute': 30, 'days': [6, 7], 'label': '', 'tune': 'gardenBells', 'vibrate': true, 'gentle': true, 'enabled': false},
  ])};
  testWidgets('alarms', (t) => _shot(t, 'alarms', const AlarmsScreen(), prefs: alarms));
  testWidgets('alarm-sheet', (t) => _shot(t, 'alarm-sheet', const AlarmsScreen(), prefs: alarms, then: (t) async {
        await t.tap(find.text('07:00').last);
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }));
  testWidgets('ringing', (t) => _shot(t, 'ringing', const RingingScreen(alarmId: 1), prefs: alarms));
}
