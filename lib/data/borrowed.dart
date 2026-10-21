import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'today.dart';

/// Test paws: borrowed from Settings to try the Shop without earning them, as many as you like. Kept apart from the
/// paws she earns, so they can all be handed back in one go.
class BorrowedNotifier extends Notifier<int> {
  static const _key = 'bloom.borrowed.v1';

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
  }

  Future<void> _save() async => (await SharedPreferences.getInstance()).setInt(_key, state);

  /// Borrow [n] paws: they land in her balance at once.
  Future<void> borrow(int n) async {
    ref.read(todayProvider.notifier).addPaws(n);
    state += n;
    await _save();
  }

  /// Hand back what's borrowed (as much of it as is still in the balance; anything already spent is forgiven).
  Future<int> giveBack() async {
    final paws = ref.read(todayProvider).paws;
    final back = state < paws ? state : paws;
    ref.read(todayProvider.notifier).addPaws(-back);
    state = 0;
    await _save();
    return back;
  }
}

final borrowedProvider = NotifierProvider<BorrowedNotifier, int>(BorrowedNotifier.new);
