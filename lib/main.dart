import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/nara_app.dart';
import 'core/platform/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Optional Firebase: initialize inside its own guarded zone so a missing
  // google-services.json can never crash the app (local-first by design).
  final container = ProviderContainer();
  try {
    await container.read(firebaseServiceProvider).initialize();
  } catch (_) {
    // Cloud sync stays inactive; reported honestly in Settings.
  }

  runApp(UncontrolledProviderScope(container: container, child: const NaraApp()));
}
