import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feel.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/coat.dart';
import '../../data/premium.dart';
import '../../data/profile.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../paywall/paywall_screen.dart';
import '../today/flow.dart';

/// Opens the cat picker: Clover, or (with Bloom Plus) the Scottish Fold or the calico, each with a
/// name of your own. Switch any time; every room changes to the cat chosen.
Future<void> showCatPicker(BuildContext context) => showBloomSheet<void>(context, (c) => const CatPicker());

class CatPicker extends ConsumerStatefulWidget {
  const CatPicker({super.key});

  @override
  ConsumerState<CatPicker> createState() => _CatPickerState();
}

class _CatPickerState extends ConsumerState<CatPicker> {
  late Coat _pick = ref.read(profileProvider).coat;
  late final _name = TextEditingController(text: ref.read(profileProvider).nameOf(_pick));

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _choose(Coat c) {
    Feel.selectionClick();
    setState(() {
      _pick = c;
      _name.text = ref.read(profileProvider).nameOf(c);
    });
  }

  void _plus() => Navigator.of(context).push(bloomRoute(Builder(builder: (c) => Scaffold(body: PaywallScreen(onDone: () => Navigator.of(c).pop())))));

  void _save() {
    final notifier = ref.read(profileProvider.notifier);
    final p = ref.read(profileProvider);
    final name = _name.text.trim();
    notifier.update(p.copyWith(coat: _pick, catName: name.isEmpty ? _pick.defaultName : name));
    Feel.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final plus = ref.watch(premiumProvider.select((p) => p.active));
    final current = ref.watch(profileProvider.select((p) => p.coat));
    final locked = _pick.plus && !plus;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Who lives with you?', style: BloomText.title),
      const SizedBox(height: 4),
      Text('Switch any time. She keeps every move, flag and paw you’ve earned.', style: BloomText.bodyMuted.copyWith(fontSize: 15)),
      const SizedBox(height: 16),
      Row(children: [
        for (final (i, c) in Coat.values.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _CatCard(coat: c, name: ref.watch(profileProvider.select((p) => p.nameOf(c))), picked: c == _pick, current: c == current, locked: c.plus && !plus, onTap: () => _choose(c))),
        ],
      ]),
      const SizedBox(height: 18),
      if (locked) ...[
        Text('${_name.text.trim().isEmpty ? _pick.defaultName : _name.text.trim()} the ${_pick.label} comes with Bloom Plus.', style: BloomText.body),
        const SizedBox(height: 14),
        LedgeButton(label: 'Try Bloom Plus', leading: const Icon(Icons.auto_awesome_rounded, color: BloomColors.onForest, size: 20), onPressed: _plus),
      ] else ...[
        Text('Her name', style: BloomText.headline.copyWith(fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          style: BloomText.headline,
          cursorColor: BloomColors.forest,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _pick.defaultName,
            hintStyle: BloomText.headline.copyWith(color: BloomColors.inkMuted),
            filled: true,
            fillColor: BloomColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.lineStrong, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.forest, width: 2)),
          ),
        ),
        const SizedBox(height: 16),
        LedgeButton(
          label: _pick == current ? 'Save her name' : 'Live with ${_name.text.trim().isEmpty ? _pick.defaultName : _name.text.trim()}',
          onPressed: _save,
        ),
      ],
    ]);
  }
}

class _CatCard extends StatelessWidget {
  const _CatCard({required this.coat, required this.name, required this.picked, required this.current, required this.locked, required this.onTap});
  final Coat coat;
  final String name;
  final bool picked, current, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: picked,
        label: '${coat.label}, $name${locked ? ', Bloom Plus' : ''}',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: BloomMotion.fast,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: picked ? BloomColors.forestSoft : BloomColors.paper,
              borderRadius: BorderRadius.circular(BloomSpace.rMd),
              border: Border.all(color: picked ? BloomColors.forest : BloomColors.line, width: 2),
            ),
            child: Column(children: [
              SizedBox(
                height: 104,
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  Opacity(opacity: locked ? .7 : 1, child: Image.asset(coat.thumb, fit: BoxFit.contain)),
                  if (locked || current)
                    Positioned(
                      top: -4,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: current ? BloomColors.mustard : BloomColors.forest, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
                        child: locked
                            ? const Icon(Icons.lock_rounded, size: 13, color: BloomColors.onForest)
                            : Text('HOME', style: BloomText.label.copyWith(fontSize: 10, color: BloomColors.ink)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Text(name, style: BloomText.headline.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(coat.label, style: BloomText.caption.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );
}
