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

  // Two players per sound, reused in turn (so a quick double tap can overlap). audioplayers'
  // AudioPool can't be used here: in low-latency mode it never hears a sound finish, so every play
  // made a new player that was never released, each running a per-frame position tracker that kept
  // the app drawing every frame forever (heat, memory). We never read positions, so those are off.
  final Map<Sfx, List<AudioPlayer>> _players = {};
  final Map<Sfx, int> _next = {};
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
        final players = <AudioPlayer>[];
        for (var i = 0; i < 2; i++) {
          final p = AudioPlayer()..positionUpdater = null;
          await p.setAudioContext(_context);
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('sfx/${sfx.file}'));
          players.add(p);
        }
        _players[sfx] = players;
      } catch (e) {
        debugPrint('Sfx: could not load ${sfx.file}: $e');
      }
    }
  }

  void play(Sfx sfx, {double volume = 1}) {
    if (!enabled) return;
    final players = _players[sfx];
    if (players == null) return;
    final i = _next[sfx] ?? 0;
    _next[sfx] = (i + 1) % players.length;
    final p = players[i];
    () async {
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
    }().catchError((Object e) {
      debugPrint('Sfx: could not play ${sfx.file}: $e');
    });
  }
}
