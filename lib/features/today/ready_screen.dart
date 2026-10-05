import 'package:flutter/material.dart';

import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/exercises.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/scene.dart';
import '../../ui/speech_bubble.dart';
import 'flow.dart';
import 'session_screen.dart';

/// She opens her eyes, perks up and asks. One decision: in, or not now.
class ReadyScreen extends StatefulWidget {
  const ReadyScreen({super.key, required this.ex});
  final Exercise ex;

  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 250), () => SfxPlayer.instance.play(Sfx.pop));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sceneH = (mq.size.height * .55).clamp(380.0, 500.0);
    return Scaffold(
      backgroundColor: BloomColors.surface,
      body: Stack(fit: StackFit.expand, children: [
        Positioned(left: 0, right: 0, top: 0, child: Scene(asset: 'assets/scenes/ready.jpg', height: sceneH, motion: SceneMotion.hop, fadeHeight: 80)),
        Positioned(
          left: 12,
          top: mq.padding.top + 8,
          child: _RoundButton(icon: Icons.close_rounded, label: 'Close', onTap: () => Navigator.of(context).pop()),
        ),
        Positioned(right: 18, top: mq.padding.top + 60, child: const PopIn(delay: Duration(milliseconds: 200), child: SpeechBubble(text: 'Ready?', invite: true, tailRight: true))),
        Positioned.fill(
          top: sceneH - 24,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + mq.padding.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RiseIn(
                child: Row(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: BloomColors.oat, borderRadius: BorderRadius.circular(BloomSpace.rMd)),
                    child: const Icon(Icons.directions_run_rounded, color: BloomColors.sageDeep, size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('TOGETHER, RIGHT NOW', style: BloomText.label),
                      Text(widget.ex.name, style: BloomText.headline),
                      Text('${widget.ex.meta} · +${widget.ex.paws} paws', style: BloomText.caption),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              RiseIn(delay: const Duration(milliseconds: 100), child: Text('She only moves if you do. Stand up, find a little space, and start together.', style: BloomText.bodyMuted)),
              const Spacer(),
              RiseIn(
                delay: const Duration(milliseconds: 180),
                child: LedgeButton(
                  label: 'I’m in',
                  glow: true,
                  onPressed: () => Navigator.of(context).pushReplacement(bloomRoute(SessionScreen(ex: widget.ex))),
                ),
              ),
              const SizedBox(height: 12),
              RiseIn(delay: const Duration(milliseconds: 240), child: LedgeButton(label: 'Not now', variant: LedgeVariant.secondary, onPressed: () => Navigator.of(context).pop())),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: BloomColors.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x14403A1E), blurRadius: 24, offset: Offset(0, 10))]),
            child: Icon(icon, color: BloomColors.ink),
          ),
        ),
      );
}

/// Shared by the session screen.
class RoundButton extends _RoundButton {
  const RoundButton({super.key, required super.icon, required super.label, required super.onTap});
}
