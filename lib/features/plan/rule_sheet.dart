import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/plan.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';

/// Add or edit a rule: which list, what it is, an icon, or a quick pick from
/// suggestions.
class RuleSheet extends ConsumerStatefulWidget {
  const RuleSheet({super.key, this.editing});
  final PlanRule? editing;

  @override
  ConsumerState<RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<RuleSheet> {
  late PlanKind _kind = widget.editing?.kind ?? (ref.read(planProvider.notifier).canAdd(PlanKind.more) ? PlanKind.more : PlanKind.skip);
  late final _text = TextEditingController(text: widget.editing?.title ?? '');
  late String _icon = widget.editing?.icon ?? 'walk';
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _editing => widget.editing != null;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(planProvider.notifier);
    final full = !_editing && !notifier.canAdd(_kind);
    final suggestions = (_kind == PlanKind.more ? moreSuggestions : skipSuggestions)
        .where((s) => !ref.read(planProvider).rules.any((r) => r.title == s.title))
        .take(4)
        .toList();
    final valid = _text.text.trim().isNotEmpty && !full;
    final icons = _kind == PlanKind.more
        ? ['walk', 'water', 'stretch', 'veg', 'stairs', 'sleep', 'sun', 'fruit']
        : ['drink', 'fastfood', 'night', 'snack', 'cake', 'screen', 'bar', 'plate'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(_editing ? 'Edit rule' : 'Add a rule', style: BloomText.title),
      const SizedBox(height: 14),
      SegmentedSwitch(
        labels: const ['Do more of', 'Skip'],
        index: _kind.index,
        onChanged: (i) => setState(() {
          _kind = PlanKind.values[i];
          if (!icons.contains(_icon)) _icon = i == 0 ? 'walk' : 'drink';
        }),
      ),
      const SizedBox(height: 16),
      Text('What is it?', style: BloomText.headline.copyWith(fontSize: 14)),
      const SizedBox(height: 6),
      TextField(
        controller: _text,
        focusNode: _focus,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.sentences,
        style: BloomText.headline,
        cursorColor: BloomColors.forest,
        decoration: InputDecoration(
          hintText: _kind == PlanKind.more ? 'e.g. Evening walk' : 'e.g. Sugary drinks',
          hintStyle: BloomText.headline.copyWith(color: BloomColors.inkMuted, fontWeight: FontWeight.w700),
          filled: true,
          fillColor: BloomColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.lineStrong, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd), borderSide: const BorderSide(color: BloomColors.forest, width: 2)),
        ),
      ),
      if (!_editing && suggestions.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in suggestions)
            _Chip(
              label: s.title,
              selected: _text.text == s.title,
              onTap: () => setState(() {
                _text.text = s.title;
                _icon = s.icon;
              }),
            ),
        ]),
      ],
      const SizedBox(height: 16),
      Text('Icon', style: BloomText.headline.copyWith(fontSize: 14)),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final k in icons)
          GestureDetector(
            onTap: () => setState(() => _icon = k),
            child: AnimatedContainer(
              duration: BloomMotion.fast,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _icon == k ? BloomColors.forestSoft : BloomColors.oat,
                borderRadius: BorderRadius.circular(BloomSpace.rSm),
                border: Border.all(color: _icon == k ? BloomColors.forest : Colors.transparent, width: 2),
              ),
              child: Icon(iconFor(k), color: _icon == k ? BloomColors.forest : BloomColors.sageDeep, size: 22),
            ),
          ),
      ]),
      if (full) ...[
        const SizedBox(height: 12),
        Text('That list already has $kMaxRules. A few rules kept beat a long list ignored.', style: BloomText.caption.copyWith(color: BloomColors.clayDeep, fontSize: 14)),
      ],
      const SizedBox(height: 18),
      LedgeButton(
        label: _editing ? 'Save rule' : 'Add rule',
        onPressed: valid
            ? () {
                if (_editing) {
                  notifier.update(widget.editing!.copyWith(kind: _kind, title: _text.text.trim(), icon: _icon));
                } else {
                  notifier.add(_kind, _text.text, _icon);
                }
                Navigator.of(context).pop();
              }
            : null,
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: BloomMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: selected ? BloomColors.forestSoft : BloomColors.paperSunk, borderRadius: BorderRadius.circular(BloomSpace.rPill)),
          child: Text(label, style: BloomText.button.copyWith(fontSize: 14, color: selected ? BloomColors.forest : BloomColors.ink)),
        ),
      );
}
