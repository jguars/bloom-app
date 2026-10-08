import 'package:flutter/material.dart';

/// The painted picture of a Shop item (gear, outfits and decor), from assets/shop/ (each at most
/// 360 px, so it decodes small as it is). Sized to [width]
/// (in a 4:3 box), or filling the space it's given when [width] is null.
class GearArt extends StatelessWidget {
  const GearArt({super.key, required this.id, this.width});
  final String id;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    return Image.asset(
      'assets/shop/$id.webp',
      width: w,
      height: w == null ? null : w * .75,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
