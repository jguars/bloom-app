import 'package:flutter/material.dart';

/// One of Bloom's painted icons (`assets/icons/<name>.webp`, gouache, in the style of the habit and craving icons),
/// used where a picture stands for a thing: move kinds, report rows, settings, title pills.
class PaintedIcon extends StatelessWidget {
  const PaintedIcon(this.name, {super.key, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset('assets/icons/$name.webp', width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}
