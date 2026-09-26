import 'package:flutter/material.dart';

import '../domain/session/game_session.dart';
import 'screens/home_screen.dart';

class SystemFallenApp extends StatelessWidget {
  const SystemFallenApp({required this.session, super.key});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema Caído',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF37D6E8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF071017),
        useMaterial3: true,
      ),
      home: HomeScreen(session: session),
    );
  }
}
