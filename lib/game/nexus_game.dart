import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../domain/config/gameplay_config.dart';
import '../domain/input/input_controller.dart';
import '../domain/session/game_session.dart';
import '../infrastructure/network/multiplayer_client.dart';
import 'audio/game_music.dart';
import 'world/playground_world.dart';
import 'world/tiled_continuous_world.dart';

class NexusGame extends FlameGame with KeyboardEvents {
  NexusGame({
    required this.input,
    required this.session,
    required this.playground,
    required this.voltChallenge,
    required this.multiplayer,
    this.multiplayerClient,
    required this.requestPause,
  }) : super(
         camera: CameraComponent.withFixedResolution(width: 1280, height: 720),
       );

  final InputController input;
  final GameSession session;
  final bool playground;
  final bool voltChallenge;
  final bool multiplayer;
  final MultiplayerClient? multiplayerClient;
  final void Function() requestPause;
  final GameplayConfig config = const GameplayConfig();
  final GameMusic _music = GameMusic();

  @override
  Future<void> onLoad() async {
    camera.viewfinder.position = Vector2(640, 360);
    if (!playground && !voltChallenge) {
      camera.viewfinder.zoom = TiledContinuousWorld.cameraZoom;
      await _setBossMusic(false);
      await world.add(
        TiledContinuousWorld(
          input: input,
          config: config,
          session: session,
          multiplayer: multiplayer,
          multiplayerClient: multiplayerClient,
          onCameraChanged: (x, y) {
            camera.viewfinder.position = Vector2(x, y);
          },
          onBossMusicChanged: (active) => unawaited(_setBossMusic(active)),
        ),
      );
    } else {
      await _setBossMusic(session.progress.roomId == 'energy_e12_volt');
      await world.add(
        PlaygroundWorld(
          input: input,
          config: config,
          playground: playground,
          voltChallenge: voltChallenge,
          session: session,
          onBossMusicChanged: (active) => unawaited(_setBossMusic(active)),
        ),
      );
    }
  }

  Future<void> _setBossMusic(bool bossActive) async {
    if (bossActive) {
      await _music.playVolt();
    } else {
      await _music.playGeneral();
    }
  }

  void pauseMusic() => unawaited(_music.pause());

  void resumeMusic() => unawaited(_music.resume());

  Future<void> disposeMusic() => _music.dispose();

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    bool down(LogicalKeyboardKey first, [LogicalKeyboardKey? second]) =>
        keysPressed.contains(first) ||
        (second != null && keysPressed.contains(second));

    input.setSource(
      GameAction.left,
      'keyboard-left',
      active: down(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft),
    );
    input.setSource(
      GameAction.right,
      'keyboard-right',
      active: down(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight),
    );
    input.setSource(
      GameAction.down,
      'keyboard-down',
      active: down(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown),
    );
    input.setSource(
      GameAction.jump,
      'keyboard-jump',
      active: keysPressed.contains(LogicalKeyboardKey.space),
    );
    input.setSource(
      GameAction.attack,
      'keyboard-attack',
      active: keysPressed.contains(LogicalKeyboardKey.keyJ),
    );
    input.setSource(
      GameAction.dash,
      'keyboard-dash',
      active: keysPressed.contains(LogicalKeyboardKey.keyK),
    );
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      requestPause();
    }
    return KeyEventResult.handled;
  }
}
