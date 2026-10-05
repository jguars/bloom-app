import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/motion.dart';
import '../app/theme.dart';

enum LedgeVariant { primary, secondary, reward, ghost }

/// The design system's pill button on a pressed ledge. Pressing sinks it 2px,
/// halves the ledge and squashes it slightly; primary and reward buttons can
/// breathe a soft glow to say "this is the next step".
class LedgeButton extends StatefulWidget {
  const LedgeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = LedgeVariant.primary,
    this.leading,
    this.glow = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final LedgeVariant variant;
  final Widget? leading;
  final bool glow;
  final bool expand;

  @override
  State<LedgeButton> createState() => _LedgeButtonState();
}

class _LedgeButtonState extends State<LedgeButton> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(vsync: this, duration: BloomMotion.fast);
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.glow) _glow.repeat();
  }

  @override
  void didUpdateWidget(LedgeButton old) {
    super.didUpdateWidget(old);
    if (widget.glow && !_glow.isAnimating) _glow.repeat();
    if (!widget.glow && _glow.isAnimating) _glow.stop();
  }

  @override
  void dispose() {
    _press.dispose();
    _glow.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null;

  ({Color fill, Color text, Color ledge, Color? edge}) get _colors {
    if (!_enabled) return (fill: BloomColors.paperSunk, text: BloomColors.inkMuted, ledge: Colors.transparent, edge: null);
    return switch (widget.variant) {
      LedgeVariant.primary => (fill: BloomColors.forest, text: BloomColors.onForest, ledge: BloomColors.forestPress, edge: null),
      LedgeVariant.secondary => (fill: BloomColors.surface, text: BloomColors.ink, ledge: BloomColors.line, edge: BloomColors.line),
      LedgeVariant.reward => (fill: BloomColors.mustard, text: BloomColors.ink, ledge: BloomColors.mustardPress, edge: null),
      LedgeVariant.ghost => (fill: Colors.transparent, text: BloomColors.forest, ledge: Colors.transparent, edge: null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final ghost = widget.variant == LedgeVariant.ghost;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _press.forward() : null,
        onTapCancel: () => _press.reverse(),
        onTapUp: _enabled
            ? (_) {
                _press.reverse();
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_press, _glow]),
          builder: (context, _) {
            final p = Curves.easeOut.transform(_press.value);
            final ledge = ghost ? 0.0 : 4 - 2 * p;
            final g = reduce || !widget.glow ? 0.0 : _glow.value;
            final glowColor = (widget.variant == LedgeVariant.reward ? BloomColors.mustard : BloomColors.forest)
                .withValues(alpha: 0.35 * (1 - g));
            return Transform.translate(
              offset: Offset(0, 2 * p),
              child: Transform.scale(
                scale: 1 - 0.03 * p,
                child: Container(
                  height: ghost ? 44 : 52,
                  width: widget.expand ? double.infinity : null,
                  padding: EdgeInsets.symmetric(horizontal: ghost ? 12 : 24),
                  decoration: BoxDecoration(
                    color: c.fill,
                    borderRadius: BorderRadius.circular(BloomSpace.rPill),
                    border: c.edge == null ? null : Border.all(color: c.edge!, width: 2),
                    boxShadow: [
                      if (ledge > 0) BoxShadow(color: c.ledge, offset: Offset(0, ledge)),
                      if (g > 0) BoxShadow(color: glowColor, spreadRadius: 9 * g),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 8)],
                      Text(widget.label, style: BloomText.button.copyWith(color: c.text)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
