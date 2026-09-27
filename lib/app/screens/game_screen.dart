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
  Timer? _hudClock;

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
    if (widget.multiplayer) {
      _hudClock = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    }
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
            if (widget.multiplayerRoom case final room?) ...[
              Positioned(
                top: 64,
                right: 16,
                child: AnimatedBuilder(
                  animation: widget.multiplayerClient!,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.groups, size: 18),
                        label: Text(room.name),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC101A22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'HORDA ${_displayHorde()}/${widget.multiplayerClient!.totalHordes}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showHordeCountdown())
                Positioned(
                  top: 12,
                  left: 72,
                  right: 72,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Chip(
                        avatar: const Icon(Icons.timer_outlined, size: 19),
                        label: Text(
                          '${_countdownTitle()} ${_remainingIntermissionSeconds()} s',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.multiplayerClient?.hordePhase ==
                  MultiplayerHordePhase.victory)
                const Positioned(
                  top: 12,
                  left: 72,
                  right: 72,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Chip(
                        avatar: Icon(Icons.emoji_events, size: 19),
                        label: Text(
                          '¡TODAS LAS HORDAS SUPERADAS!',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hudClock?.cancel();
    _input.releaseAll();
    unawaited(_game.disposeMusic());
    super.dispose();
  }

  int _displayHorde() {
    final client = widget.multiplayerClient;
    if (client == null) return 1;
    if (client.hordePhase == MultiplayerHordePhase.intermission) {
      return (client.hordeNumber + 1).clamp(1, client.totalHordes);
    }
    return client.hordeNumber.clamp(1, client.totalHordes);
  }

  bool _showHordeCountdown() {
    final phase = widget.multiplayerClient?.hordePhase;
    return phase == MultiplayerHordePhase.preparing ||
        phase == MultiplayerHordePhase.intermission;
  }

  String _countdownTitle() =>
      widget.multiplayerClient?.hordePhase == MultiplayerHordePhase.preparing
      ? 'PRIMERA HORDA EN'
      : 'SIGUIENTE HORDA EN';

  int _remainingIntermissionSeconds() {
    final endsAt = widget.multiplayerClient?.intermissionEndsAt;
    if (endsAt == null) return 0;
    final milliseconds = endsAt.difference(DateTime.now()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil();
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
