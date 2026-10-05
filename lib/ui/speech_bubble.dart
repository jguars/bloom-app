import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/theme.dart';

/// Everything Clover says. Pops in whenever the line changes, then bobs.
class SpeechBubble extends StatefulWidget {
  const SpeechBubble({super.key, required this.text, this.invite = false, this.tailRight = false, this.maxWidth = 210});
  final String text;
  final bool invite;
  final bool tailRight;
  final double maxWidth;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.invite ? BloomColors.ink : BloomColors.surface;
    final style = widget.invite
        ? BloomText.title.copyWith(color: BloomColors.surface, fontSize: 22)
        : BloomText.bubble.copyWith(fontSize: 16, height: 22 / 16);
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, reduce ? 0 : -5 * (0.5 - 0.5 * math.cos(_bob.value * 2 * math.pi))),
        child: child,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: BloomMotion.pop,
        transitionBuilder: (child, a) => ScaleTransition(scale: Tween(begin: .6, end: 1.0).animate(a), alignment: widget.tailRight ? Alignment.bottomRight : Alignment.bottomLeft, child: FadeTransition(opacity: a, child: child)),
        child: Column(
          key: ValueKey(widget.text),
          crossAxisAlignment: widget.tailRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10)), BoxShadow(color: BloomColors.line, offset: Offset(0, 1))],
              ),
              child: Text(widget.text, style: style),
            ),
            Padding(
              padding: EdgeInsets.only(left: widget.tailRight ? 0 : 26, right: widget.tailRight ? 26 : 0),
              child: CustomPaint(size: const Size(18, 9), painter: _Tail(bg)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tail extends CustomPainter {
  _Tail(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..quadraticBezierTo(s.width * .55, s.height * .4, s.width * .5, s.height)
      ..quadraticBezierTo(s.width * .45, s.height * .4, 0, 0);
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Tail old) => old.color != color;
}
