import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/theme.dart';

/// Everything Clover says. Pops in whenever the line changes, then bobs.
class SpeechBubble extends StatefulWidget {
  const SpeechBubble({super.key, required this.text, this.alternate, this.invite = false, this.tailRight = false, this.maxWidth = 210});
  final String text;

  /// A second line, said in turn with [text] each time the bubble comes back.
  final String? alternate;
  final bool invite;
  final bool tailRight;
  final double maxWidth;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  /// Bubbles don't stay up: each one shows for [_on], hides, and comes back every [_every] (taking
  /// turns with [SpeechBubble.alternate] when there is one). A new
  /// line shows straight away and restarts the rhythm. The rhythm rests while its screen is hidden
  /// or the app is idle (TickerMode off).
  static const _on = Duration(seconds: 3), _every = Duration(seconds: 15);
  bool _shown = true;
  bool _alt = false;
  Timer? _cycle;
  String get _text => _alt && widget.alternate != null ? widget.alternate! : widget.text;
  ValueListenable<TickerModeData>? _ticking;

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = TickerMode.getValuesNotifier(context);
    if (n != _ticking) {
      _ticking?.removeListener(_onTicking);
      _ticking = n..addListener(_onTicking);
    }
  }

  void _onTicking() {
    if (_ticking!.value.enabled) {
      _show();
    } else {
      _cycle?.cancel();
    }
  }

  void _show() {
    _cycle?.cancel();
    if (!_shown) setState(() => _shown = true);
    _cycle = Timer(_on, _hide);
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _shown = false);
    _cycle = Timer(_every - _on, () {
      if (!mounted) return;
      if (widget.alternate != null) _alt = !_alt;
      _show();
    });
  }

  @override
  void didUpdateWidget(SpeechBubble old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _alt = false;
      _show();
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _ticking?.removeListener(_onTicking);
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.invite ? BloomColors.ink : BloomColors.surface;
    final style = widget.invite ? BloomText.title.copyWith(color: BloomColors.surface, fontSize: 22) : BloomText.bubble.copyWith(fontSize: 16, height: 22 / 16);
    final reduce = MediaQuery.of(context).disableAnimations;
    final bubble = AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(offset: Offset(0, reduce ? 0 : -5 * (0.5 - 0.5 * math.cos(_bob.value * 2 * math.pi))), child: child),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: BloomMotion.pop,
        transitionBuilder: (child, a) => ScaleTransition(
          scale: Tween(begin: .6, end: 1.0).animate(a),
          alignment: widget.tailRight ? Alignment.bottomRight : Alignment.bottomLeft,
          child: FadeTransition(opacity: a, child: child),
        ),
        child: Column(
          key: ValueKey(_text),
          crossAxisAlignment: widget.tailRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10)),
                  BoxShadow(color: BloomColors.line, offset: Offset(0, 1)),
                ],
              ),
              child: Text(_text, style: style),
            ),
            Padding(
              padding: EdgeInsets.only(left: widget.tailRight ? 0 : 26, right: widget.tailRight ? 26 : 0),
              child: CustomPaint(size: const Size(18, 9), painter: _Tail(bg)),
            ),
          ],
        ),
      ),
    );
    return IgnorePointer(
      ignoring: !_shown,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: Duration(milliseconds: _shown ? 220 : 320),
        child: AnimatedScale(
          scale: _shown ? 1 : .85,
          duration: Duration(milliseconds: _shown ? 420 : 320),
          curve: _shown ? BloomMotion.pop : Curves.easeIn,
          alignment: widget.tailRight ? Alignment.bottomRight : Alignment.bottomLeft,
          child: bubble,
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
