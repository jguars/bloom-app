import 'package:flutter/material.dart';

import '../app/feel.dart';
import '../app/motion.dart';
import '../app/theme.dart';
import 'paw.dart';

/// `shadow-card`: resting cards.
const cardShadow = [BoxShadow(color: BloomColors.line, offset: Offset(0, 1)), BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10))];

BoxDecoration cardDecoration({Color color = BloomColors.surface, double radius = BloomSpace.rLg}) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: cardShadow);

/// A surface card.
class BloomCard extends StatelessWidget {
  const BloomCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(width: double.infinity, padding: padding, decoration: cardDecoration(), child: child);
    return onTap == null ? card : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}

/// Uppercase eyebrow.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: BloomText.label);
}

/// A small number with a caption above it.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: cardDecoration(radius: BloomSpace.rMd),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: BloomText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: BloomMotion.base,
            transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: BloomMotion.pop), child: FadeTransition(opacity: a, child: c)),
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
            child: Text(value, key: ValueKey(value), style: BloomText.number.copyWith(fontSize: 22, height: 28 / 22, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]),
      );
}

/// A status pill. Status always pairs colour with an icon and a word.
class BloomTag extends StatelessWidget {
  const BloomTag({super.key, required this.text, this.icon, this.tone = TagTone.done});
  final String text;
  final IconData? icon;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TagTone.done => (BloomColors.forestSoft, BloomColors.forest),
      TagTone.neutral => (BloomColors.paperSunk, BloomColors.ink),
      TagTone.reward => (BloomColors.mustardSoft, BloomColors.ink),
      TagTone.warn => (BloomColors.claySoft, BloomColors.clayDeep),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Text(text, style: BloomText.caption.copyWith(color: fg, fontWeight: FontWeight.w800, fontVariations: const [FontVariation('wght', 800)])),
      ]),
    );
  }
}

enum TagTone { done, neutral, reward, warn }

/// An on/off switch: forest track, a knob that springs across.
class BloomToggle extends StatelessWidget {
  const BloomToggle({super.key, required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        label: label,
        child: GestureDetector(
          onTap: () {
            Feel.selectionClick();
            onChanged(!value);
          },
          child: AnimatedContainer(
            duration: BloomMotion.base,
            width: 52,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: value ? BloomColors.forest : BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rPill), border: Border.all(color: value ? BloomColors.forest : BloomColors.line, width: 1)),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: BloomMotion.spring,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x332E3826), blurRadius: 4, offset: Offset(0, 2))])),
            ),
          ),
        ),
      );
}

/// A row inside a grouped card: title, caption and a trailing control
/// (a chevron when it opens something).
class GroupRow extends StatelessWidget {
  const GroupRow({super.key, required this.title, this.caption, this.trailing, this.onTap, this.last = false, this.leading});
  final String title;
  final String? caption;
  final Widget? trailing, leading;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => _Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: BloomColors.line))),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: BloomText.headline.copyWith(fontSize: 16, height: 22 / 16)),
                if (caption != null) Text(caption!, style: BloomText.caption),
              ]),
            ),
            trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, color: BloomColors.inkMuted) : const SizedBox()),
          ]),
        ),
      );
}

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: cardDecoration(radius: BloomSpace.rMd),
        clipBehavior: Clip.antiAlias,
        child: Material(type: MaterialType.transparency, child: Column(children: children)),
      );
}

/// Darkens slightly while pressed.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        Feel.selectionClick();
        widget.onTap!();
      },
      child: AnimatedContainer(duration: BloomMotion.fast, color: _down ? BloomColors.paperSunk : Colors.transparent, child: widget.child),
    );
  }
}

/// A pushed page off a room (weekly summary, weight history…): back button,
/// a small "from" label, the title, then content rising in.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.from, required this.title, required this.children, this.bottom});
  final String from, title;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: BloomColors.paper,
      body: Column(children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, mq.padding.top + 8, 16, 24),
            children: [
              Row(children: [
                Semantics(
                  button: true,
                  label: 'Back to $from',
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle, boxShadow: cardShadow),
                      child: const Icon(Icons.chevron_left_rounded, color: BloomColors.ink, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(from, style: BloomText.caption.copyWith(fontSize: 15)),
              ]),
              const SizedBox(height: 16),
              RiseIn(child: Text(title, style: BloomText.display)),
              const SizedBox(height: 16),
              for (var i = 0; i < children.length; i++) RiseIn(delay: BloomMotion.stagger * (i + 1), child: children[i]),
            ],
          ),
        ),
        if (bottom != null) Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + mq.padding.bottom), child: bottom),
      ]),
    );
  }
}
