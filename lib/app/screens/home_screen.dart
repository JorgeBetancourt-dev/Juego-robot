import 'package:flutter/material.dart';

import '../../domain/session/game_session.dart';
import 'game_screen.dart';
import 'multiplayer_lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.session, super.key});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'SISTEMA CAÍDO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF78F3FF),
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'DIRECTIVA 01  RESTABLECER EL NÚCLEO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8DA5B5),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (session.hasSave)
                      FilledButton(
                        onPressed: () => _openGame(context, playground: false),
                        child: const Text('CONTINUAR'),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () async {
                        await session.startNewGame();
                        if (context.mounted) {
                          _openGame(context, playground: false);
                        }
                      },
                      child: const Text('NUEVA PARTIDA'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: () => _openMultiplayer(context),
                      child: const Text('MODO MULTIJUGADOR'),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Prueba de recorrido y colisiones del mapa continuo',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF657887)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openGame(BuildContext context, {required bool playground}) {
    _openGameWithSession(context, gameSession: session, playground: playground);
  }

  void _openMultiplayer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MultiplayerLobbyScreen()),
    );
  }

  void _openGameWithSession(
    BuildContext context, {
    required GameSession gameSession,
    required bool playground,
    bool voltChallenge = false,
    bool multiplayer = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          session: gameSession,
          playground: playground,
          voltChallenge: voltChallenge,
          multiplayer: multiplayer,
        ),
      ),
    );
  }
}
