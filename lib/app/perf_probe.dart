import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Frame-timing probe for finding jank on a real device, release build included.
/// Off unless built with `--dart-define=PERF=true`. Every two seconds it logs
/// (tag `flutter`, search for `[perf]`) how many frames were drawn and how long
/// the UI thread (build/layout/paint) and raster thread took, plus every
/// route change, so slow numbers can be matched to the screen on show.
class PerfProbe {
  static const enabled = bool.fromEnvironment('PERF');

  static final observer = _RouteLog();
  static final _timings = <FrameTiming>[];
  static DateTime _windowStart = DateTime.now();

  static void start() {
    if (!enabled) return;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    debugPrint('[perf] probe on');
  }

  /// Tabs aren't routes; the shell reports them here.
  static void tab(String name) {
    if (!enabled) return;
    observer.current = 'tab:$name';
    debugPrint('[perf] tab -> $name');
  }

  static void _onTimings(List<FrameTiming> list) {
    _timings.addAll(list);
    final now = DateTime.now();
    if (now.difference(_windowStart) < const Duration(seconds: 2)) return;
    final secs = now.difference(_windowStart).inMilliseconds / 1000;
    _windowStart = now;
    if (_timings.isEmpty) return;
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = _timings.map((t) => ms(t.buildDuration)).toList()..sort();
    final raster = _timings.map((t) => ms(t.rasterDuration)).toList()..sort();
    double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    double p90(List<double> v) => v[(v.length * .9).floor().clamp(0, v.length - 1)];
    // A frame's budget follows the panel's current rate (8.3 ms at 120 Hz).
    final hz = WidgetsBinding.instance.platformDispatcher.displays.first.refreshRate;
    final budget = 1000 / hz;
    final slow = _timings.where((t) => ms(t.buildDuration) > budget || ms(t.rasterDuration) > budget).length;
    debugPrint('[perf] ${(_timings.length / secs).toStringAsFixed(0)} fps · '
        'ui avg ${avg(build).toStringAsFixed(1)} p90 ${p90(build).toStringAsFixed(1)} max ${build.last.toStringAsFixed(1)} · '
        'raster avg ${avg(raster).toStringAsFixed(1)} p90 ${p90(raster).toStringAsFixed(1)} max ${raster.last.toStringAsFixed(1)} · '
        'slow $slow/${_timings.length} @${hz.round()}Hz · at ${observer.current}');
    _timings.clear();
  }
}

class _RouteLog extends NavigatorObserver {
  String current = 'start';

  String _name(Route<dynamic>? r) {
    if (r == null) return '?';
    if (r.settings.name != null) return r.settings.name!;
    if (r is ModalBottomSheetRoute) return 'sheet';
    if (r is MaterialPageRoute) return r.builder(navigator!.context).runtimeType.toString();
    if (r is PageRouteBuilder) return r.pageBuilder(navigator!.context, kAlwaysCompleteAnimation, kAlwaysCompleteAnimation).runtimeType.toString();
    return r.runtimeType.toString();
  }

  void _log(String what, Route<dynamic>? top) {
    if (!PerfProbe.enabled) return;
    current = _name(top);
    debugPrint('[perf] $what -> $current');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _log('push', route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _log('pop', previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _log('replace', newRoute);
}
