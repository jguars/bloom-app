import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/profile.dart';

/// Clover's two daily nudges: a morning look at the plan and an evening
/// "how did today go?". Local notifications only; nothing leaves the phone.
abstract final class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Future<void>? _starting;

  static const _morningId = 1, _eveningId = 2;

  /// The reminder the user tapped to open the app ('morning' or 'evening').
  /// The shell listens and goes to the right room.
  static final tapped = ValueNotifier<String?>(null);
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('clover', 'Clover’s reminders', channelDescription: 'A gentle nudge in the morning and the evening.', importance: Importance.defaultImportance),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() => _starting ??= _init();

  static Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );
      _ready = true;
      // Opened from a reminder while the app wasn't running.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) tapped.value = launch!.notificationResponse?.payload;
    } catch (e) {
      debugPrint('Reminders: not available: $e');
    }
  }

  /// Asks the OS for permission to notify. True if allowed (or not needed).
  static Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('Reminders: permission failed: $e');
    }
    return false;
  }

  /// Puts the schedule in line with [p]: each reminder repeats daily.
  static Future<void> schedule(Profile p) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _morningId);
      await _plugin.cancel(id: _eveningId);
      if (p.morning) await _daily(_morningId, p.morningAt, p.catName, 'Morning! Shall we look at today’s plan together?', 'morning');
      if (p.evening) await _daily(_eveningId, p.eveningAt, p.catName, 'How did today go? Come tell me.', 'evening');
    } catch (e) {
      debugPrint('Reminders: scheduling failed: $e');
    }
  }

  static Future<void> _daily(int id, int minutes, String title, String body, String payload) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
