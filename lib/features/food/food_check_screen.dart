import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/food_check.dart';
import '../../data/plan.dart';
import '../../ui/bits.dart';
import '../../ui/clover_rive.dart';
import '../../ui/ledge_button.dart';
import '../../ui/paw.dart';
import '../../ui/speech_bubble.dart';

enum _Stage { start, checking, result, offline }

/// "Is this on my plan?": snap or pick a photo, Clover takes a look, and a
/// kind verdict comes back. Until a checker is connected it says so plainly
/// and can show an example result.
class FoodCheckScreen extends ConsumerStatefulWidget {
  const FoodCheckScreen({super.key});

  @override
  ConsumerState<FoodCheckScreen> createState() => _FoodCheckScreenState();
}

class _FoodCheckScreenState extends ConsumerState<FoodCheckScreen> with SingleTickerProviderStateMixin {
  var _stage = _Stage.start;
  Uint8List? _photo;
  FoodVerdict? _verdict;
  late final _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 80);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = bytes;
        _stage = _Stage.checking;
      });
      _check();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn’t open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.')));
    }
  }

  Future<void> _check() async {
    SfxPlayer.instance.play(Sfx.whoosh);
    _scan.repeat();
    try {
      final v = await ref.read(foodCheckerProvider).check(_photo!, ref.read(planProvider).rules);
      if (!mounted) return;
      _show(v);
    } on FoodCheckNotConnected {
      if (!mounted) return;
      _scan.stop();
      setState(() => _stage = _Stage.offline);
    } catch (_) {
      if (!mounted) return;
      _scan.stop();
      setState(() => _stage = _Stage.offline);
    }
  }

  void _show(FoodVerdict v) {
    _scan.stop();
    SfxPlayer.instance.play(v.fit == FoodFit.skip ? Sfx.pop : Sfx.chime);
    Feel.mediumImpact();
    setState(() {
      _verdict = v;
      _stage = _Stage.result;
    });
  }

  String get _line => switch (_stage) {
        _Stage.start => 'Show me what you’ve got!',
        _Stage.checking => 'Hmm, let me have a look…',
        _Stage.offline => 'My glasses aren’t on yet!',
        _Stage.result => switch (_verdict!.fit) {
            FoodFit.good => 'Yum, a good pick!',
            FoodFit.okay => 'Fine in moderation.',
            FoodFit.skip => 'That one’s on our skip list.',
          },
      };

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: BloomColors.paper,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, mq.padding.top + 8, 16, 24 + mq.padding.bottom),
        children: [
          Row(children: [
            Semantics(
              button: true,
              label: 'Back',
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
            Text('Plan', style: BloomText.caption.copyWith(fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          Text('Is this on my plan?', style: BloomText.display),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              SizedBox(width: 140, height: 170, child: LiveClover(action: _stage == _Stage.result && _verdict!.fit == FoodFit.good ? CloverAction.cheer : CloverAction.rest, eyesOpen: _stage == _Stage.checking)),
              Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 70), child: SpeechBubble(text: _line))),
            ]),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: BloomMotion.base,
            child: KeyedSubtree(key: ValueKey(_stage), child: _body()),
          ),
        ],
      ),
    );
  }

  Widget _photoCard() => ClipRRect(
        borderRadius: BorderRadius.circular(BloomSpace.rLg),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(fit: StackFit.expand, children: [
            if (_photo != null) Image.memory(_photo!, fit: BoxFit.cover) else const ColoredBox(color: BloomColors.oat),
            if (_stage == _Stage.checking)
              AnimatedBuilder(
                animation: _scan,
                builder: (context, _) => Align(
                  alignment: Alignment(0, -1 + 2 * _scan.value),
                  child: Container(height: 6, decoration: BoxDecoration(color: BloomColors.mustard, boxShadow: [BoxShadow(color: BloomColors.mustard.withValues(alpha: .6), blurRadius: 18)])),
                ),
              ),
          ]),
        ),
      );

  Widget _body() => switch (_stage) {
        _Stage.start => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Snap your plate or a drink. Clover checks it against your plan and suggests a swap if it helps.', style: BloomText.bodyMuted),
            const SizedBox(height: 20),
            LedgeButton(label: 'Take a photo', leading: const Icon(Icons.photo_camera_rounded, color: BloomColors.onForest), onPressed: () => _pick(ImageSource.camera)),
            const SizedBox(height: 10),
            LedgeButton(label: 'Choose from gallery', variant: LedgeVariant.secondary, leading: const Icon(Icons.photo_library_outlined, color: BloomColors.ink), onPressed: () => _pick(ImageSource.gallery)),
            const SizedBox(height: 6),
            LedgeButton(label: 'See an example', variant: LedgeVariant.ghost, onPressed: () => _show(demoVerdict(ref.read(planProvider).rules))),
          ]),
        _Stage.checking => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _photoCard(),
            const SizedBox(height: 12),
            Text('Checking against your plan…', style: BloomText.bodyMuted, textAlign: TextAlign.center),
          ]),
        _Stage.offline => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _photoCard(),
            const SizedBox(height: 14),
            BloomCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const BloomTag(text: 'Not connected yet', icon: Icons.cloud_off_rounded, tone: TagTone.neutral),
                const SizedBox(height: 8),
                Text('Food check needs an AI service', style: BloomText.headline),
                const SizedBox(height: 4),
                Text('The photo flow is ready. Once a checker is connected, results appear here. Nothing was uploaded.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 14),
            LedgeButton(label: 'See an example result', variant: LedgeVariant.secondary, onPressed: () => _show(demoVerdict(ref.read(planProvider).rules))),
            LedgeButton(label: 'Try another photo', variant: LedgeVariant.ghost, onPressed: () => setState(() => _stage = _Stage.start)),
          ]),
        _Stage.result => _Result(verdict: _verdict!, photo: _photoCard(), hasPhoto: _photo != null, onAgain: () => setState(() {
              _photo = null;
              _stage = _Stage.start;
            })),
      };
}

class _Result extends StatelessWidget {
  const _Result({required this.verdict, required this.photo, required this.hasPhoto, required this.onAgain});
  final FoodVerdict verdict;
  final Widget photo;
  final bool hasPhoto;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, word) = switch (verdict.fit) {
      FoodFit.good => (TagTone.done, Icons.check_rounded, 'A good pick'),
      FoodFit.okay => (TagTone.reward, Icons.balance_rounded, 'Fine in moderation'),
      FoodFit.skip => (TagTone.warn, Icons.close_rounded, 'On your skip list'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (hasPhoto) ...[photo, const SizedBox(height: 14)],
      PopIn(
        child: BloomCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BloomTag(text: word, icon: icon, tone: tone),
              const Spacer(),
              if (verdict.demo) const BloomTag(text: 'Example', tone: TagTone.neutral),
            ]),
            const SizedBox(height: 10),
            Text(verdict.name, style: BloomText.title),
            if (verdict.rule != null) Text('Matches “${verdict.rule!.title}”', style: BloomText.caption),
            const SizedBox(height: 8),
            Text(verdict.note, style: BloomText.body),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      LedgeButton(label: 'Check something else', variant: LedgeVariant.secondary, onPressed: onAgain),
    ]);
  }
}
