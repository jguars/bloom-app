import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short UI sounds, synthesised by avelo/sfx/make_sfx.py (copied from Avelo).
enum Sfx {
  /// Countdown 3-2-1.
  tick('tick.wav'),

  /// The session starts.
  go('go.wav'),

  /// She looks at you and asks "Ready?".
  pop('pop.wav'),

  /// The timer finishes.
  done('done.wav'),

  /// The celebration sheet opens.
  cheer('cheer.wav');

  const Sfx(this.file);
  final String file;
}

/// Plays [Sfx] with low latency. They mix with the user's music rather than
/// pausing it, and stay silent when the phone is on silent.
class SfxPlayer {
  SfxPlayer._();
  static final instance = SfxPlayer._();

  final Map<Sfx, AudioPool> _pools = {};
  bool enabled = true;

  static final _context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
    respectSilence: true,
  ).build();

  /// Preloads every sound. Safe to call once at startup; failures only mean
  /// the app stays quiet.
  Future<void> init() async {
    for (final sfx in Sfx.values) {
      try {
        _pools[sfx] = await AudioPool.create(
          source: AssetSource('sfx/${sfx.file}'),
          maxPlayers: 2,
          audioContext: _context,
          playerMode: PlayerMode.lowLatency,
        );
      } catch (e) {
        debugPrint('Sfx: could not load ${sfx.file}: $e');
      }
    }
  }

  void play(Sfx sfx, {double volume = 1}) {
    if (!enabled) return;
    final pool = _pools[sfx];
    if (pool == null) return;
    pool.start(volume: volume).catchError((Object e) {
      debugPrint('Sfx: could not play ${sfx.file}: $e');
      return () async {};
    });
  }
}
