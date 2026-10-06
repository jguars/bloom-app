import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/feel.dart';
import '../app/reminders.dart';
import '../app/sfx.dart';

/// Names, onboarding answers and app preferences.
class Profile {
  const Profile({
    this.name = '',
    this.catName = 'Clover',
    this.sound = true,
    this.haptics = true,
    this.pounds = false,
    this.onboarded = false,
    this.reason = '',
    this.activity = '',
    this.limits = const {},
    this.morning = false,
    this.evening = false,
    this.morningAt = 8 * 60,
    this.eveningAt = 20 * 60 + 30,
    this.loaded = false,
  });

  /// The user's first name; empty until they set it.
  final String name;
  final String catName;
  final bool sound, haptics;

  /// Show weights in pounds. Weights are always stored in kilograms.
  final bool pounds;

  /// Finished the first-run flow.
  final bool onboarded;

  /// Onboarding answers: why they're here, a normal day, areas to go easy on.
  final String reason, activity;
  final Set<String> limits;

  /// Daily reminders, with their times in minutes after midnight.
  final bool morning, evening;
  final int morningAt, eveningAt;

  final bool loaded;

  String get displayName => name.trim().isEmpty ? 'You' : name.trim();

  Profile copyWith({
    String? name,
    String? catName,
    bool? sound,
    bool? haptics,
    bool? pounds,
    bool? onboarded,
    String? reason,
    String? activity,
    Set<String>? limits,
    bool? morning,
    bool? evening,
    int? morningAt,
    int? eveningAt,
  }) =>
      Profile(
        name: name ?? this.name,
        catName: catName ?? this.catName,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        pounds: pounds ?? this.pounds,
        onboarded: onboarded ?? this.onboarded,
        reason: reason ?? this.reason,
        activity: activity ?? this.activity,
        limits: limits ?? this.limits,
        morning: morning ?? this.morning,
        evening: evening ?? this.evening,
        morningAt: morningAt ?? this.morningAt,
        eveningAt: eveningAt ?? this.eveningAt,
        loaded: true,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'catName': catName,
        'sound': sound,
        'haptics': haptics,
        'pounds': pounds,
        'onboarded': onboarded,
        'reason': reason,
        'activity': activity,
        'limits': limits.toList(),
        'morning': morning,
        'evening': evening,
        'morningAt': morningAt,
        'eveningAt': eveningAt,
      };

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
        name: j['name'] as String? ?? '',
        catName: j['catName'] as String? ?? 'Clover',
        sound: j['sound'] as bool? ?? true,
        haptics: j['haptics'] as bool? ?? true,
        pounds: j['pounds'] as bool? ?? false,
        onboarded: j['onboarded'] as bool? ?? false,
        reason: j['reason'] as String? ?? '',
        activity: j['activity'] as String? ?? '',
        limits: ((j['limits'] as List?) ?? const []).cast<String>().toSet(),
        morning: j['morning'] as bool? ?? false,
        evening: j['evening'] as bool? ?? false,
        morningAt: (j['morningAt'] as num?)?.toInt() ?? 8 * 60,
        eveningAt: (j['eveningAt'] as num?)?.toInt() ?? 20 * 60 + 30,
        loaded: true,
      );
}

class ProfileNotifier extends Notifier<Profile> {
  static const _key = 'bloom.profile.v1';

  @override
  Profile build() {
    _load();
    return const Profile();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _apply(raw == null ? const Profile().copyWith() : Profile.fromJson(jsonDecode(raw) as Map<String, Object?>));
  }

  void _apply(Profile p) {
    final first = !state.loaded;
    final remindersChanged = p.morning != state.morning || p.evening != state.evening || p.morningAt != state.morningAt || p.eveningAt != state.eveningAt || p.catName != state.catName;
    state = p;
    SfxPlayer.instance.enabled = p.sound;
    Feel.enabled = p.haptics;
    if (first || remindersChanged) Reminders.schedule(p);
  }

  Future<void> update(Profile p) async {
    _apply(p);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(p.toJson()));
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, Profile>(ProfileNotifier.new);

/// "8:00", "20:30".
String clockText(int minutes) => '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Formats weights in the user's unit, with a true minus sign.
class Units {
  const Units(this.pounds);
  final bool pounds;

  static const _lb = 2.20462;
  String get name => pounds ? 'lb' : 'kg';

  /// Step for the weight stepper, in kg.
  double get stepKg => pounds ? .2 / _lb : .1;

  double show(double kg) => pounds ? kg * _lb : kg;
  String value(double kg) => show(kg).toStringAsFixed(1);
  String weight(double kg) => '${value(kg)} $name';

  /// Like [weight] but without a needless ".0": "0.7 kg", "82 kg".
  String short(double kg) {
    final v = show(kg);
    final s = v.toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s} $name';
  }

  /// "−0.6 kg", "+0.2 kg", "0.0 kg".
  String change(double kg) {
    final v = show(kg);
    if (v.abs() < .05) return '0.0 $name';
    return '${v < 0 ? '−' : '+'}${v.abs().toStringAsFixed(1)} $name';
  }
}

final unitsProvider = Provider<Units>((ref) => Units(ref.watch(profileProvider.select((p) => p.pounds))));
