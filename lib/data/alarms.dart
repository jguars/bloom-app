import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wake-up tunes, rendered by tools/sfx/make_sfx.py.
enum AlarmTune {
  morningPurr('Morning purr', 'assets/alarm/morning_purr.wav'),
  gardenBells('Garden bells', 'assets/alarm/garden_bells.wav'),
  pawPatter('Paw patter', 'assets/alarm/paw_patter.wav');

  const AlarmTune(this.title, this.path);
  final String title, path;
}

class AlarmItem {
  const AlarmItem({
    required this.id,
    required this.hour,
    required this.minute,
    this.days = const {1, 2, 3, 4, 5},
    this.label = '',
    this.tune = AlarmTune.morningPurr,
    this.vibrate = true,
    this.gentle = true,
    this.enabled = true,
  });

  final int id, hour, minute;

  /// Weekdays it repeats on (1 = Monday … 7 = Sunday); empty rings once.
  final Set<int> days;
  final String label;
  final AlarmTune tune;
  final bool vibrate;

  /// Fade the volume up over 30 seconds.
  final bool gentle;
  final bool enabled;

  String get time => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// The next moment this alarm rings after [now].
  DateTime nextAfter(DateTime now) {
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    if (days.isEmpty) return t;
    for (var i = 0; i < 8; i++) {
      if (days.contains(t.weekday)) return t;
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  String get repeatLabel {
    if (days.isEmpty) return 'Once';
    if (days.length == 7) return 'Every day';
    if (setEquals(days, {1, 2, 3, 4, 5})) return 'Weekdays';
    if (setEquals(days, {6, 7})) return 'Weekends';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (days.toList()..sort()).map((d) => names[d - 1]).join(', ');
  }

  AlarmItem copyWith({int? hour, int? minute, Set<int>? days, String? label, AlarmTune? tune, bool? vibrate, bool? gentle, bool? enabled}) => AlarmItem(
        id: id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        days: days ?? this.days,
        label: label ?? this.label,
        tune: tune ?? this.tune,
        vibrate: vibrate ?? this.vibrate,
        gentle: gentle ?? this.gentle,
        enabled: enabled ?? this.enabled,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'days': days.toList(),
        'label': label,
        'tune': tune.name,
        'vibrate': vibrate,
        'gentle': gentle,
        'enabled': enabled,
      };

  factory AlarmItem.fromJson(Map<String, Object?> j) => AlarmItem(
        id: (j['id'] as num).toInt(),
        hour: (j['hour'] as num).toInt(),
        minute: (j['minute'] as num).toInt(),
        days: ((j['days'] as List?) ?? const []).cast<int>().toSet(),
        label: j['label'] as String? ?? '',
        tune: AlarmTune.values.asNameMap()[j['tune']] ?? AlarmTune.morningPurr,
        vibrate: j['vibrate'] as bool? ?? true,
        gentle: j['gentle'] as bool? ?? true,
        enabled: j['enabled'] as bool? ?? true,
      );
}

/// Snoozes use their own id range so they never replace the alarm itself.
const kSnoozeIdOffset = 100000;
const kSnooze = Duration(minutes: 9);

class AlarmsNotifier extends Notifier<List<AlarmItem>> {
  static const _key = 'bloom.alarms.v1';

  @override
  List<AlarmItem> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    state = [for (final j in jsonDecode(raw) as List) AlarmItem.fromJson((j as Map).cast<String, Object?>())];
    await _syncAll();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final a in state) a.toJson()]));
  }

  /// Notifications and exact alarms need the user's OK on newer Android.
  Future<void> ensurePermissions() async {
    if (!Platform.isAndroid) return;
    try {
      await Permission.notification.request();
      if (await Permission.scheduleExactAlarm.isDenied) await Permission.scheduleExactAlarm.request();
    } catch (e) {
      debugPrint('Alarms: permission request failed: $e');
    }
  }

  Future<void> save(AlarmItem item) async {
    final i = state.indexWhere((a) => a.id == item.id);
    state = (i < 0 ? [...state, item] : [for (final a in state) a.id == item.id ? item : a])
      ..sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
    await _save();
    await _sync(item);
  }

  Future<void> toggle(AlarmItem item, bool on) => save(item.copyWith(enabled: on));

  Future<void> remove(AlarmItem item) async {
    state = state.where((a) => a.id != item.id).toList();
    await _save();
    await _stop(item.id);
  }

  int newId() {
    var id = DateTime.now().millisecondsSinceEpoch % 90000 + 1;
    while (state.any((a) => a.id == id)) {
      id++;
    }
    return id;
  }

  AlarmItem? byId(int id) {
    final base = id >= kSnoozeIdOffset ? id - kSnoozeIdOffset : id;
    for (final a in state) {
      if (a.id == base) return a;
    }
    return null;
  }

  AlarmSettings _settings(AlarmItem a, DateTime at, {int? id}) => AlarmSettings(
        id: id ?? a.id,
        dateTime: at,
        assetAudioPath: a.tune.path,
        loopAudio: true,
        vibrate: a.vibrate,
        volumeSettings: a.gentle ? VolumeSettings.fade(volume: .9, fadeDuration: const Duration(seconds: 30)) : const VolumeSettings.fixed(volume: .9),
        notificationSettings: NotificationSettings(
          title: a.label.isEmpty ? 'Good morning!' : a.label,
          body: 'Clover is up and stretching. Join her!',
          stopButton: 'I’m up',
        ),
        androidFullScreenIntent: true,
        warningNotificationOnKill: false,
      );

  Future<void> _stop(int id) async {
    try {
      await Alarm.stop(id);
    } catch (_) {}
  }

  Future<void> _sync(AlarmItem a) async {
    await _stop(a.id);
    if (!a.enabled) return;
    try {
      await Alarm.set(alarmSettings: _settings(a, a.nextAfter(DateTime.now())));
    } catch (e) {
      debugPrint('Alarms: could not set ${a.time}: $e');
    }
  }

  Future<void> _syncAll() async {
    for (final a in state) {
      await _sync(a);
    }
  }

  /// Stopped from the ringing screen: repeating alarms move to their next
  /// day, one-off alarms switch off.
  Future<void> dismissed(int ringingId) async {
    await _stop(ringingId);
    final a = byId(ringingId);
    if (a == null) return;
    if (a.days.isEmpty) {
      await save(a.copyWith(enabled: false));
    } else {
      await _sync(a);
    }
  }

  Future<void> snooze(int ringingId) async {
    await _stop(ringingId);
    final a = byId(ringingId);
    if (a == null) return;
    try {
      await Alarm.set(alarmSettings: _settings(a, DateTime.now().add(kSnooze), id: a.id + kSnoozeIdOffset));
    } catch (_) {}
    if (a.days.isNotEmpty) await _sync(a);
  }
}

final alarmsProvider = NotifierProvider<AlarmsNotifier, List<AlarmItem>>(AlarmsNotifier.new);
