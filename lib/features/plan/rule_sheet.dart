import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/sfx.dart';
import '../../app/theme.dart';
import '../../data/plan.dart';
import '../../ui/ledge_button.dart';
import '../../ui/room_frame.dart';
import '../../ui/rule_icon.dart';

/// Add or edit a rule: which list, what it is, how often (once a day, or a few times with a daily
/// goal and a rest before it comes back up), an icon, or a quick pick from suggestions.
class RuleSheet extends ConsumerStatefulWidget {
  const RuleSheet({super.key, this.editing, this.kind = PlanKind.more});
  final PlanRule? editing;
  final PlanKind kind;

  @override
  ConsumerState<RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<RuleSheet> {
  late PlanKind _kind = widget.editing?.kind ?? widget.kind;
  late bool _repeats = (widget.editing?.goal ?? 1) > 1;
  late int _goal = (widget.editing?.goal ?? 1) > 1 ? widget.editing!.goal : 3;
  late int _rest = widget.editing?.rest ?? 90;
  static const _rests = [30, 60, 90, 120, 180];
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

  /// Removes the rule being edited, with an undo in case it was a slip.
  void _remove() {
    final notifier = ref.read(planProvider.notifier);
    final rule = widget.editing!;
    final at = notifier.remove(rule.id);
    SfxPlayer.instance.play(Sfx.swipe);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      persist: false,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      backgroundColor: BloomColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BloomSpace.rMd)),
      content: Text('Removed “${rule.title}”', style: BloomText.body.copyWith(color: BloomColors.surface), maxLines: 1, overflow: TextOverflow.ellipsis),
      action: SnackBarAction(label: 'Undo', textColor: BloomColors.mustard, onPressed: () => notifier.restore(rule, at)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(planProvider.notifier);
    final suggestions = (_kind == PlanKind.more ? moreSuggestions : skipSuggestions)
        .where((s) => !ref.read(planProvider).rules.any((r) => r.title == s.title))
        .take(4)
        .toList();
    final valid = _text.text.trim().isNotEmpty;
    final icons = _kind == PlanKind.more
        ? ['walk', 'water', 'stretch', 'veg', 'stairs', 'sleep', 'sun', 'fruit']
        : ['drink', 'fastfood', 'night', 'snack', 'cake', 'screen', 'bar', 'plate'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(_editing ? 'Edit rule' : (_kind == PlanKind.more ? 'Add a Do' : 'Add a Don’t'), style: BloomText.title),
      const SizedBox(height: 14),
      SegmentedSwitch(
        labels: const ['Do', 'Don’t'],
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
          hintText: _kind == PlanKind.more ? 'Evening walk' : 'Sugary drinks',
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
                _repeats = s.goal > 1;
                if (_repeats) {
                  _goal = s.goal;
                  _rest = s.rest;
                }
              }),
            ),
        ]),
      ],
      const SizedBox(height: 16),
      Text('How often?', style: BloomText.headline.copyWith(fontSize: 14)),
      const SizedBox(height: 8),
      SegmentedSwitch(labels: const ['Once a day', 'A few times'], index: _repeats ? 1 : 0, onChanged: (i) => setState(() => _repeats = i == 1)),
      AnimatedSize(
        duration: BloomMotion.base,
        curve: BloomMotion.enter,
        alignment: Alignment.topCenter,
        child: !_repeats
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(_kind == PlanKind.more ? 'Daily goal' : 'Say no up to', style: BloomText.body)),
                    _Step(icon: Icons.remove_rounded, label: 'Fewer', onTap: _goal > 2 ? () => setState(() => _goal--) : null),
                    SizedBox(width: 64, child: Text('$_goal×', textAlign: TextAlign.center, style: BloomText.headline)),
                    _Step(icon: Icons.add_rounded, label: 'More', onTap: _goal < 12 ? () => setState(() => _goal++) : null),
                  ]),
                  const SizedBox(height: 10),
                  Text('Back up the list after', style: BloomText.body),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in _rests) _Chip(label: m % 60 == 0 ? '${m ~/ 60} h' : '$m min', selected: _rest == m, onTap: () => setState(() => _rest = m)),
                  ]),
                ]),
              ),
      ),
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
              child: Center(child: RuleIcon(k, size: 34, color: _icon == k ? BloomColors.forest : BloomColors.sageDeep)),
            ),
          ),
      ]),
      const SizedBox(height: 18),
      LedgeButton(
        label: _editing ? 'Save rule' : 'Add rule',
        onPressed: valid
            ? () {
                if (_editing) {
                  notifier.update(widget.editing!.copyWith(kind: _kind, title: _text.text.trim(), icon: _icon, goal: _repeats ? _goal : 1, rest: _rest));
                } else {
                  notifier.add(_kind, _text.text, _icon, goal: _repeats ? _goal : 1, rest: _rest);
                }
                Navigator.of(context).pop();
              }
            : null,
      ),
      if (_editing) ...[
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: _remove,
            icon: const Icon(Icons.delete_outline_rounded, color: BloomColors.clayDeep),
            label: Text('Remove rule', style: BloomText.button.copyWith(fontSize: 15, color: BloomColors.clayDeep)),
          ),
        ),
      ],
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

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: BloomColors.paperSunk, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: onTap == null ? BloomColors.line : BloomColors.ink, size: 20),
          ),
        ),
      );
}
