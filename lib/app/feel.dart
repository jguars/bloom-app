import 'package:flutter/services.dart';

/// Haptics that respect the user's "Haptics" setting. Use these instead of
/// [HapticFeedback] directly.
abstract final class Feel {
  static bool enabled = true;

  static void lightImpact() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
