import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/home_widgets.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/today.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';

/// "Clover on your home screen": live previews of both widgets that bob
/// gently; Add hands off to the launcher's pin dialog.
class WidgetSheet extends ConsumerWidget {
  const WidgetSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(todayProvider);
    final pose = s.done >= kDailyGoal ? 'cheer' : 'rest';
    final android = !Platform.environment.containsKey('FLUTTER_TEST') && Platform.isAndroid;
    Future<void> add(BloomWidget w) async {
      Feel.mediumImpact();
      final ok = await requestPin(w);
      if (!context.mounted) return;
      if (ok) {
        SfxPlayer.instance.play(Sfx.chime);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Long-press your home screen, tap Widgets, then find Bloom.')));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Clover on your home screen', style: BloomText.title),
      const SizedBox(height: 4),
      Text(android ? 'She keeps you company and shows today’s moves.' : 'Home-screen widgets are on Android for now.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      const SizedBox(height: 16),
      RiseIn(
        child: _Preview(
          width: double.infinity,
          height: 132,
          child: Row(children: [
            Container(
              width: 96,
              decoration: BoxDecoration(color: BloomColors.mustardSoft, borderRadius: BorderRadius.circular(18)),
              child: Image.asset('assets/widget/widget_clover_$pose.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TODAY WITH CLOVER', style: BloomText.label.copyWith(fontSize: 11)),
                Text(s.done == 0 ? 'Ready when you are!' : 'That felt good! One more?', style: BloomText.headline.copyWith(fontSize: 16), maxLines: 2),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: s.done / kDailyGoal, minHeight: 10, color: BloomColors.forest, backgroundColor: BloomColors.paperSunk)),
                const SizedBox(height: 6),
                Text('${s.done} of $kDailyGoal today · ${s.paws} paws', style: BloomText.caption.copyWith(color: BloomColors.ink)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      LedgeButton(label: 'Add Today widget', variant: LedgeVariant.secondary, onPressed: android ? () => add(BloomWidget.today) : null),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        RiseIn(
          delay: const Duration(milliseconds: 80),
          child: _Preview(
            width: 132,
            height: 132,
            child: Stack(children: [
              Positioned.fill(child: Image.asset('assets/widget/widget_clover_$pose.png', fit: BoxFit.contain)),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                  child: Text('${s.done}/$kDailyGoal', style: BloomText.caption.copyWith(color: BloomColors.ink)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Clover', style: BloomText.headline),
            Text(BloomWidget.clover.caption, style: BloomText.caption),
            const SizedBox(height: 10),
            LedgeButton(label: 'Add', variant: LedgeVariant.secondary, onPressed: android ? () => add(BloomWidget.clover) : null),
          ]),
        ),
      ]),
    ]);
  }
}

/// A widget preview card that floats a little.
class _Preview extends StatefulWidget {
  const _Preview({required this.width, required this.height, required this.child});
  final double width, height;
  final Widget child;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(offset: Offset(0, -3 * Curves.easeInOut.transform(_c.value)), child: child),
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BloomColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x262E3826), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: widget.child,
        ),
      );
}
