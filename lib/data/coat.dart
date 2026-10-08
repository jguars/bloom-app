import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

/// Which cat lives with you. Every cat shares Clover's rig and animations: the others are only her
/// rig pieces painted in another coat (`assets/cats/<coat>/`), handed to the Rive files in place of
/// hers as they load. The new cats come with Bloom Plus.
enum Coat {
  clover('Original', 'Clover', 'assets/cats/thumb-clover.png'),
  fold('Scottish Fold', 'Mochi', 'assets/cats/thumb-fold.png'),
  calico('Calico', 'Maple', 'assets/cats/thumb-calico.png');

  const Coat(this.label, this.defaultName, this.thumb);
  final String label, defaultName, thumb;

  bool get plus => this != clover;

  /// The cat the scenes draw: the one chosen, while it's allowed (see BloomApp).
  static final current = ValueNotifier<Coat>(Coat.clover);

  /// Her pieces, by the names of Clover's image assets in the Rive files (`clover_<piece>`).
  static const _pieces = ['body_noface', 'body_noeyes', 'ear_l', 'ear_r', 'arm_l', 'arm_r', 'leg_l', 'leg_r', 'tail', 'flower'];
  static final _bytes = <Coat, Future<Map<String, Uint8List>>>{};

  /// Reads this cat's pieces, once, before a file that needs them is decoded.
  Future<Map<String, Uint8List>> _load() => _bytes[this] ??= () async {
        final out = <String, Uint8List>{};
        for (final p in _pieces) {
          out['clover_$p'] = (await rootBundle.load('assets/cats/$name/$p.png')).buffer.asUint8List();
        }
        return out;
      }();

  /// Loads a Rive file with this cat's pieces in place of Clover's.
  Future<rive.File?> open(String asset, rive.Factory factory) async {
    if (this == clover) return rive.File.asset(asset, riveFactory: factory);
    final pieces = await _load();
    return rive.File.asset(
      asset,
      riveFactory: factory,
      assetLoader: (a, _) {
        final bytes = a is rive.ImageAsset ? pieces[a.name] : null;
        if (bytes == null) return false;
        a.decode(bytes);
        return true;
      },
    );
  }
}
