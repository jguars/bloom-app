import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/feel.dart';
import '../app/sfx.dart';

/// Names and app preferences.
class Profile {
  const Profile({this.name = '', this.catName = 'Clover', this.sound = true, this.haptics = true, this.pounds = false});

  /// The user's first name; empty until they set it.
  final String name;
  final String catName;
  final bool sound, haptics;

  /// Show weights in pounds. Weights are always stored in kilograms.
  final bool pounds;

  String get displayName => name.trim().isEmpty ? 'You' : name.trim();

  Profile copyWith({String? name, String? catName, bool? sound, bool? haptics, bool? pounds}) => Profile(
        name: name ?? this.name,
        catName: catName ?? this.catName,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        pounds: pounds ?? this.pounds,
      );

  Map<String, Object?> toJson() => {'name': name, 'catName': catName, 'sound': sound, 'haptics': haptics, 'pounds': pounds};

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
        name: j['name'] as String? ?? '',
        catName: j['catName'] as String? ?? 'Clover',
        sound: j['sound'] as bool? ?? true,
        haptics: j['haptics'] as bool? ?? true,
        pounds: j['pounds'] as bool? ?? false,
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
    if (raw != null) _apply(Profile.fromJson(jsonDecode(raw) as Map<String, Object?>));
  }

  void _apply(Profile p) {
    state = p;
    SfxPlayer.instance.enabled = p.sound;
    Feel.enabled = p.haptics;
  }

  Future<void> update(Profile p) async {
    _apply(p);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(p.toJson()));
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, Profile>(ProfileNotifier.new);

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

  /// "−0.6 kg", "+0.2 kg", "0.0 kg".
  String change(double kg) {
    final v = show(kg);
    if (v.abs() < .05) return '0.0 $name';
    return '${v < 0 ? '−' : '+'}${v.abs().toStringAsFixed(1)} $name';
  }
}

final unitsProvider = Provider<Units>((ref) => Units(ref.watch(profileProvider.select((p) => p.pounds))));
