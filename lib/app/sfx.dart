import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short UI sounds, synthesised by tools/sfx/make_sfx.py (numpy + scipy).
enum Sfx {
  tap('tap.wav'),
  whoosh('whoosh.wav'),
  swipe('swipe.wav'),
  nope('nope.wav'),
  tick('tick.wav'),
  go('go.wav'),
  done('done.wav'),
  pop('pop.wav'),
  purr('purr.wav'),
  coin('coin.wav'),
  check('check.wav'),
  uncheck('uncheck.wav'),
  cheer('cheer.wav'),
  unlock('unlock.wav'),
  flag('flag.wav'),
  chime('chime.wav'),
  breatheIn('breathe_in.wav'),
  breatheOut('breathe_out.wav'),
  drop('drop.wav');

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
