import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/gate.dart';
import 'app/reminders.dart';
import 'app/sfx.dart';
import 'app/theme.dart';
import 'ui/clover_rive.dart';
import 'ui/fx_layer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloverRive.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  SfxPlayer.instance.init();
  Reminders.init();
  runApp(const ProviderScope(child: BloomApp()));
}

class BloomApp extends StatelessWidget {
  const BloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom',
      debugShowCheckedModeBanner: false,
      theme: bloomTheme(),
      builder: (context, child) => FxLayer.wrap(child!),
      home: const AppGate(),
    );
  }
}
