import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../domain/input/input_controller.dart';
import '../../domain/session/game_session.dart';
import '../../game/nexus_game.dart';
import '../../infrastructure/network/multiplayer_client.dart';
import '../controls/touch_controls.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.session,
    required this.playground,
    this.voltChallenge = false,
    this.multiplayer = false,
    this.multiplayerClient,
    this.multiplayerRoom,
    super.key,
  });

  final GameSession session;
  final bool playground;
  final bool voltChallenge;
  final bool multiplayer;
  final MultiplayerClient? multiplayerClient;
  final MultiplayerRoom? multiplayerRoom;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final InputController _input;
  late final NexusGame _game;

  @override
  void initState() {
    super.initState();
    _input = InputController();
    _game = NexusGame(
      input: _input,
      session: widget.session,
      playground: widget.playground,
      voltChallenge: widget.voltChallenge,
      multiplayer: widget.multiplayer,
      multiplayerClient: widget.multiplayerClient,
      requestPause: _showPause,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget<NexusGame>(game: _game, autofocus: true),
            TouchControls(
              input: _input,
              session: widget.session,
              playground: widget.playground,
              voltChallenge: widget.voltChallenge,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Pausa',
                onPressed: _showPause,
                icon: const Icon(Icons.pause),
              ),
            ),
            if (widget.multiplayerRoom case final room?)
              Positioned(
                top: 64,
                right: 16,
                child: Chip(
                  avatar: const Icon(Icons.groups, size: 18),
                  label: Text(room.name),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _input.releaseAll();
    unawaited(_game.disposeMusic());
    super.dispose();
  }

  Future<void> _showPause() async {
    if (!mounted || _game.paused) return;
    _game.pauseEngine();
    _game.pauseMusic();
    _input.releaseAll();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('PAUSA'),
        content: const Text('La simulación está detenida.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('SALIR AL INICIO'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('REANUDAR'),
          ),
        ],
      ),
    );
    if (mounted) {
      _game.resumeEngine();
      _game.resumeMusic();
    }
  }
}
