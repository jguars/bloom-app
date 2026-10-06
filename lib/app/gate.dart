import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile.dart';
import '../features/onboarding/onboarding_flow.dart';
import 'shell.dart';
import 'theme.dart';

/// First launch goes through onboarding; after that, straight into the house.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider.select((p) => (p.loaded, p.onboarded)));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      child: !p.$1
          ? const ColoredBox(key: ValueKey('wait'), color: BloomColors.paper, child: SizedBox.expand())
          : p.$2
              ? const Shell(key: ValueKey('house'))
              : const OnboardingFlow(key: ValueKey('welcome')),
    );
  }
}
