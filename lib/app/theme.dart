import 'package:flutter/material.dart';

/// Colours from the Bloom design system (tokens.json). Names match the tokens.
abstract final class BloomColors {
  static const paper = Color(0xFFF8F1E1);
  static const paperSunk = Color(0xFFF0E6CF);
  static const surface = Color(0xFFFFFBF3);
  static const line = Color(0xFFE3D6B9);
  static const lineStrong = Color(0xFF958764);
  static const ink = Color(0xFF2E3826);
  static const inkMuted = Color(0xFF5C6450);
  static const forest = Color(0xFF4A6838);
  static const forestPress = Color(0xFF34492A);
  static const onForest = Color(0xFFFFFBF3);
  static const forestSoft = Color(0xFFE2EAD3);
  static const oat = Color(0xFFEBDCC4);
  static const sage = Color(0xFFA9BC93);
  static const sageDeep = Color(0xFF5E7F4A);
  static const mustard = Color(0xFFD6B23C);
  static const mustardPress = Color(0xFFA9871F);
  static const mustardSoft = Color(0xFFF6E8B8);
  static const clay = Color(0xFFC9714B);
  static const clayDeep = Color(0xFF9A4A2B);
  static const claySoft = Color(0xFFF5DECF);
  static const sky = Color(0xFFD7E8EE);
  static const skyDeep = Color(0xFF36697F);
  static const coral = Color(0xFFEE7B67);
  static const blush = Color(0xFFE3B5A4);

  /// The floating tab bar's liquid glass: a smoky forest tint (so it reads against the cream panels),
  /// a frosted pill for the open room, and cream icons.
  static const glassTop = Color(0xA6577447);
  static const glassBottom = Color(0xC72F4426);
  static const glassPill = Color(0x33FFFBF3);
  static const onGlass = Color(0xFFFFFBF3);
  static const onGlassMuted = Color(0xB8E9EFDD);

  /// Confetti in Clover's colours.
  static const confetti = [mustard, sage, coral, sageDeep, surface, blush];
}

/// Spacing and radius tokens.
abstract final class BloomSpace {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0, s8 = 32.0, s12 = 48.0;
  static const rSm = 10.0, rMd = 16.0, rLg = 24.0, rXl = 32.0, rPill = 999.0;
}

/// Type styles from the design system. Nunito is a variable font, so every
/// style sets the `wght` axis as well as the weight.
abstract final class BloomText {
  static TextStyle _n(double size, double lh, int w, {double ls = 0, Color color = BloomColors.ink}) => TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        height: lh / size,
        fontWeight: FontWeight.values[(w ~/ 100) - 1],
        fontVariations: [FontVariation('wght', w.toDouble())],
        letterSpacing: ls,
        color: color,
      );

  static final displayXl = _n(44, 48, 900, ls: -0.5);
  static final display = _n(30, 36, 900, ls: -0.3);
  static final title = _n(22, 28, 800);
  static final headline = _n(18, 24, 800);
  static final bubble = _n(17, 24, 700);
  static final body = _n(16, 24, 600);
  static final bodyMuted = _n(16, 24, 600, color: BloomColors.inkMuted);
  static final button = _n(17, 20, 800);
  static final caption = _n(13, 18, 700, color: BloomColors.inkMuted);
  static final label = _n(12, 16, 800, ls: 0.8, color: BloomColors.inkMuted);
  static final number = _n(20, 24, 900);
}

ThemeData bloomTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BloomColors.forest,
      primary: BloomColors.forest,
      surface: BloomColors.surface,
    ),
    scaffoldBackgroundColor: BloomColors.paper,
    fontFamily: 'Nunito',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(textTheme: base.textTheme.apply(bodyColor: BloomColors.ink, displayColor: BloomColors.ink));
}
