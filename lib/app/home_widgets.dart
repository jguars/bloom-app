import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../data/journal.dart';
import '../data/profile.dart';
import '../data/today.dart';

/// Home-screen widgets (Android). Names match the Kotlin providers in
/// android/app/src/main/kotlin/com/setir/bloom/BloomWidgets.kt.
enum BloomWidget {
  today('com.setir.bloom.BloomTodayWidget', 'Today', 'Clover, her line and today’s moves'),
  clover('com.setir.bloom.BloomCloverWidget', 'Clover', 'Just her, with today’s count');

  const BloomWidget(this.androidName, this.title, this.caption);
  final String androidName, title, caption;
}

/// Pushes today's state to the widgets whenever it changes.
class HomeWidgetSync {
  HomeWidgetSync(this._ref);
  final WidgetRef _ref;
  Timer? _debounce;

  void start() {
    if (!Platform.isAndroid) return;
    _ref.listenManual(todayProvider, (_, _) => schedule());
    _ref.listenManual(journalProvider, (_, _) => schedule());
    _ref.listenManual(profileProvider, (_, _) => schedule());
    schedule();
  }

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), push);
  }

  Future<void> push() async {
    if (!Platform.isAndroid) return;
    final s = _ref.read(todayProvider);
    final j = _ref.read(journalProvider);
    final name = _ref.read(profileProvider).name.trim();
    final missed = s.done == 0 && j.dayNumber >= 1 && j.on(j.todayDate.subtract(const Duration(days: 1))).moves == 0;
    final line = switch (s.done) {
      0 when missed => 'I saved you a spot on the mat.',
      0 => name.isEmpty ? 'Ready when you are!' : 'Ready when you are, $name!',
      _ when s.done < kDailyGoal => 'That felt good! One more?',
      _ => 'We did it today. Nap time?',
    };
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<int>('done', s.done),
        HomeWidget.saveWidgetData<String>('day', s.day),
        HomeWidget.saveWidgetData<int>('goal', kDailyGoal),
        HomeWidget.saveWidgetData<String>('line', line),
        HomeWidget.saveWidgetData<int>('paws', s.paws),
        HomeWidget.saveWidgetData<bool>('missed', missed),
      ]);
      for (final w in BloomWidget.values) {
        await HomeWidget.updateWidget(qualifiedAndroidName: w.androidName);
      }
    } catch (_) {
      // Widgets are a nicety; never let them break the app.
    }
  }
}

/// Asks the launcher to place [widget] on the home screen. False when the
/// launcher can't, so the caller can show the manual steps instead.
Future<bool> requestPin(BloomWidget widget) async {
  if (!Platform.isAndroid) return false;
  try {
    if (!(await HomeWidget.isRequestPinWidgetSupported() ?? false)) return false;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: widget.androidName);
    return true;
  } catch (_) {
    return false;
  }
}
