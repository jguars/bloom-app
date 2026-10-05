import 'package:flutter/animation.dart';

/// Motion tokens from the design system.
abstract final class BloomMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);

  /// Things entering overshoot once.
  static const spring = Cubic(0.2, 1.3, 0.35, 1);
  static const pop = Cubic(0.2, 1.6, 0.4, 1);
  static const enter = Curves.easeOutCubic;
  static const leave = Curves.easeInCubic;

  /// Stagger between items in a group.
  static const stagger = Duration(milliseconds: 40);
}
