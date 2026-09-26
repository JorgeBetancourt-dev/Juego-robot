import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'domain/session/game_session.dart';
import 'infrastructure/persistence/shared_preferences_save_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final repository = SharedPreferencesSaveRepository();
  final session = GameSession(repository);
  await session.load();

  runApp(SystemFallenApp(session: session));
}
