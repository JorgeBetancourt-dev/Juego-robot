import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' as flutter;

import '../../domain/bosses/volt_controller.dart';
import '../../domain/combat/combat_controller.dart';
import '../../domain/config/gameplay_config.dart';
import '../../domain/input/input_controller.dart';
import '../../domain/movement/aabb.dart';
import '../../domain/movement/player_motor.dart';
import '../../domain/session/game_session.dart';
import '../../infrastructure/network/multiplayer_client.dart';
import '../art/environment_assets.dart';
import '../art/sprite_assets.dart';
import 'tiled_enemy_actor.dart';
import 'tiled_map_data.dart';

/// Mundo continuo construido directamente desde el TMX diseñado en Tiled.
///
/// El archivo se carga una sola vez. El render recorre únicamente las celdas
/// próximas a la cámara, por lo que el escenario puede crecer sin volver a la
/// antigua transición de una sala de 1280x720 a otra.
class TiledContinuousWorld extends Component {
  TiledContinuousWorld({
    required this.input,
    required this.config,
    required this.session,
    this.multiplayer = false,
    this.multiplayerClient,
    required this.onCameraChanged,
    required this.onBossMusicChanged,
  });

  static const double viewportWidth = 1280;
  static const double viewportHeight = 720;
  static const double cameraZoom = 1.18;
  static const double cameraVerticalOffset = 80;
  static const double hudSafeInsetX = 60;
  static const double hudSafeInsetY = 30;
  static const Vec2d _initialSpawn = Vec2d(4000, 4406);

  final InputController input;
  final GameplayConfig config;
  final GameSession session;
  final bool multiplayer;
  final MultiplayerClient? multiplayerClient;
  final void Function(double x, double y) onCameraChanged;
  final void Function(bool active) onBossMusicChanged;

  late final TiledMapData map;
  late final PlayerMotor motor;
  late final CombatController combat;
  late Vec2d _respawnPosition;
  String? _activeCheckpointId;
  final List<TiledEnemyActor> _enemies = [];
  final Map<String, Vec2d> _remotePositions = {};
  final Set<String> _downStrikeHitIds = {};
  TiledVoltActor? _volt;
  EnvironmentAssets? _environment;
  GameSpriteAssets? _sprites;
  late final TextPaint _smallPaint;
  late final TextPaint _playerNamePaint;
  double _elapsed = 0;
  double _deathTimer = 0;
  double _cameraX = 0;
  double _cameraY = 0;
  bool _bossEncounterActive = false;
  bool _voltVictoryRecorded = false;
  double _messageTimer = 0;
  String _message = '';

  final Paint _backgroundPaint = Paint()..color = const Color(0xFF7C8182);
  final Paint _fallbackSolid = Paint()..color = const Color(0xFF16314E);
  final Paint _fallbackHazard = Paint()..color = const Color(0xFFE64242);
  final Paint _playerPaint = Paint()..color = const Color(0xFF55DFEF);
  final Paint _hurtPaint = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _dashPaint = Paint()..color = const Color(0xFFB776FF);
  final Paint _attackPaint = Paint()..color = const Color(0x66FF3939);
  final Paint _enemyPaint = Paint()..color = const Color(0xFFFF973D);
  final Paint _projectilePaint = Paint()..color = const Color(0xFFFFE15C);
  final Paint _telegraphPaint = Paint()..color = const Color(0x99FFE04A);

  MovementAbilities get _abilities {
    final unlocked = session.progress.abilities;
    return MovementAbilities(
      dash: unlocked.contains('dash'),
      wallJump: unlocked.contains('wallJump'),
      downStrike: unlocked.contains('downStrike'),
      doubleJump: unlocked.contains('doubleJump'),
    );
  }

  @override
  Future<void> onLoad() async {
    map = await TiledMapData.load(
      path: multiplayer
          ? TiledMapData.multiplayerAssetPath
          : TiledMapData.assetPath,
      profile: multiplayer
          ? TiledMapProfile.multiplayer
          : TiledMapProfile.campaign,
    );
    final savedCheckpoint = _savedCheckpoint();
    _activeCheckpointId = savedCheckpoint?.id;
    _respawnPosition =
        savedCheckpoint?.respawn(
          playerWidth: config.playerWidth,
          playerHeight: config.playerHeight,
        ) ??
        _safeSpawn();
    motor = PlayerMotor(config: config, initialPosition: _respawnPosition);
    combat = CombatController(config: config);
    _smallPaint = TextPaint(
      style: const flutter.TextStyle(
        color: Color(0xFFE5F5FB),
        fontSize: 14,
        fontFamily: 'monospace',
        shadows: [flutter.Shadow(color: Color(0xFF071017), blurRadius: 3)],
      ),
    );
    _playerNamePaint = TextPaint(
      style: const flutter.TextStyle(
        color: Color(0xFFFF3B30),
        fontSize: 15,
        fontFamily: 'monospace',
        fontWeight: flutter.FontWeight.w700,
        shadows: [
          flutter.Shadow(
            color: Color(0xFF071017),
            blurRadius: 4,
            offset: Offset(1, 1),
          ),
        ],
      ),
    );
    _environment = await EnvironmentAssets.load();
    _sprites = await GameSpriteAssets.load();
    if (!multiplayer) _loadEnemyMarkers();
    if (multiplayer) multiplayerClient?.markArenaReady();
    _cameraX = motor.body.left + motor.body.width / 2;
    _cameraY = motor.body.top + motor.body.height / 2 - cameraVerticalOffset;
    _publishCamera();
  }

  TiledCheckpointMarker? _savedCheckpoint() {
    for (final checkpoint in map.checkpointMarkers) {
      if (checkpoint.id == session.progress.checkpointId) return checkpoint;
    }
    return null;
  }

  void _loadEnemyMarkers() {
    var index = 0;
    for (final marker in map.enemyMarkers) {
      if (marker.type == TiledEnemyType.volt) {
        _volt = TiledVoltActor(markerX: marker.x, markerY: marker.y);
        continue;
      }
      _enemies.add(
        TiledEnemyActor(
          id: '${marker.type.name}_${index++}',
          type: marker.type,
          markerX: marker.x,
          markerY: marker.y,
        ),
      );
    }
  }

  Vec2d _safeSpawn() {
    final maxX = math.max(32.0, map.worldWidth - config.playerWidth - 32);
    final maxY = math.max(32.0, map.worldHeight - config.playerHeight - 32);
    final spawnIndex = multiplayerClient?.spawnIndex ?? 0;
    final initialSpawn = multiplayer
        ? map.multiplayerSpawnFor(
                spawnIndex: spawnIndex,
                playerWidth: config.playerWidth,
                playerHeight: config.playerHeight,
              ) ??
              const Vec2d(480, 378)
        : _initialSpawn;
    return Vec2d(
      initialSpawn.x.clamp(32.0, maxX).toDouble(),
      initialSpawn.y.clamp(32.0, maxY).toDouble(),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final safeDt = math.min(dt, 0.05);
    _elapsed += safeDt;
    _messageTimer = math.max(0, _messageTimer - safeDt);
    combat.update(safeDt);
    final frame = input.consumeFrame();
    if (frame.attackPressed && !frame.downHeld) combat.startAttack();
    motor.update(
      safeDt,
      combat.canControl ? frame : _blockedFrame(),
      map.solids,
      oneWayPlatforms: map.oneWayPlatforms,
      abilities: _abilities,
    );
    if (multiplayer) _updateMultiplayer(safeDt);
    _updateCheckpoints();
    _updateEnemies(safeDt);
    _resolveEnemyCombat();
    _resolveHazards();
    _updateDeath(safeDt);
    _updateCamera(safeDt);
  }

  PlayerInputFrame _blockedFrame() => const PlayerInputFrame(
    horizontal: 0,
    downHeld: false,
    jumpHeld: false,
    jumpPressed: false,
    attackPressed: false,
    dashPressed: false,
  );

  void _updateMultiplayer(double dt) {
    final client = multiplayerClient;
    if (client == null) return;
    _syncHordeEnemies(client);
    client.sendPlayerState(
      x: motor.body.left,
      y: motor.body.top,
      facing: motor.facing,
      animation: _playerAnimation(),
    );
    _remotePositions.removeWhere(
      (id, _) => !client.remotePlayers.containsKey(id),
    );
    for (final remote in client.remotePlayers.values) {
      final target = Vec2d(remote.x, remote.y);
      final current = _remotePositions.putIfAbsent(remote.id, () => target);
      final blend = 1 - math.exp(-14 * dt);
      _remotePositions[remote.id] = Vec2d(
        current.x + (target.x - current.x) * blend,
        current.y + (target.y - current.y) * blend,
      );
    }
  }

  void _syncHordeEnemies(MultiplayerClient client) {
    final snapshots = client.hordeEnemies;
    _enemies.removeWhere((enemy) => !snapshots.containsKey(enemy.id));
    for (final snapshot in snapshots.values) {
      TiledEnemyActor? actor;
      for (final candidate in _enemies) {
        if (candidate.id == snapshot.id) {
          actor = candidate;
          break;
        }
      }
      actor ??= TiledEnemyActor(
        id: snapshot.id,
        type: switch (snapshot.type) {
          'watcher' => TiledEnemyType.watcher,
          'drone' => TiledEnemyType.drone,
          'volt' => TiledEnemyType.volt,
          _ => TiledEnemyType.patrol,
        },
        markerX: 0,
        markerY: 0,
        spawnX: snapshot.x,
        spawnY: snapshot.y,
        maxHealth: snapshot.type == 'volt' ? 12 : 3,
      );
      if (!_enemies.contains(actor)) _enemies.add(actor);
      actor.setNetworkHealth(snapshot.health);
    }
  }

  void _updateCheckpoints() {
    for (final checkpoint in map.checkpointMarkers) {
      if (!checkpoint.trigger.overlaps(motor.body) ||
          checkpoint.id == _activeCheckpointId) {
        continue;
      }
      _activeCheckpointId = checkpoint.id;
      _respawnPosition = checkpoint.respawn(
        playerWidth: config.playerWidth,
        playerHeight: config.playerHeight,
      );
      combat.restore();
      _message = 'PUNTO DE GUARDADO ACTUALIZADO';
      _messageTimer = 2.6;
      unawaited(session.activateCheckpoint(checkpoint.id, 'continuous_map'));
      break;
    }
  }

  void _updateEnemies(double dt) {
    for (final enemy in _enemies) {
      enemy.update(
        dt,
        multiplayer ? _closestPlayerTo(enemy.body) : motor.body,
        map.solids,
        map.oneWayPlatforms,
      );
    }
    final volt = _volt;
    if (volt == null || session.progress.bossesDefeated.contains('volt')) {
      _setBossEncounter(false);
      return;
    }
    final encounter = volt.update(
      dt,
      motor.body,
      map.solids,
      map.oneWayPlatforms,
      map.worldWidth,
      _voltArena,
    );
    _setBossEncounter(encounter && !volt.controller.defeated);
  }

  Aabb _closestPlayerTo(Aabb enemyBody) {
    final players = <Aabb>[motor.body];
    for (final position in _remotePositions.values) {
      players.add(
        Aabb(position.x, position.y, config.playerWidth, config.playerHeight),
      );
    }
    final enemyCenter = enemyBody.left + enemyBody.width / 2;
    players.sort((first, second) {
      final firstDistance = ((first.left + first.width / 2) - enemyCenter)
          .abs();
      final secondDistance = ((second.left + second.width / 2) - enemyCenter)
          .abs();
      return firstDistance.compareTo(secondDistance);
    });
    return players.first;
  }

  // Sala cerrada dibujada entre las celdas 270..308 y 181..194 del TMX.
  // La música de jefe solo se activa cuando M-0 entra físicamente aquí.
  Aabb get _voltArena => Aabb(
    (270 - map.originCellX) * map.tileWidth.toDouble(),
    (181 - map.originCellY) * map.tileHeight.toDouble(),
    39 * map.tileWidth.toDouble(),
    14 * map.tileHeight.toDouble(),
  );

  void _setBossEncounter(bool active) {
    if (_bossEncounterActive == active) return;
    _bossEncounterActive = active;
    onBossMusicChanged(active);
  }

  void _resolveEnemyCombat() {
    final playerBody = motor.body;
    final playerAttack = combat.phase == AttackPhase.active
        ? combat.attackHitbox(playerBody, motor.facing)
        : null;
    if (motor.state != PlayerMotionState.downStriking) {
      _downStrikeHitIds.clear();
    }
    for (final enemy in _enemies) {
      if (enemy.alive &&
          playerAttack != null &&
          playerAttack.overlaps(enemy.body) &&
          combat.tryHit(enemy.id)) {
        _damageEnemy(enemy);
      }
      if (enemy.alive &&
          motor.state == PlayerMotionState.downStriking &&
          playerBody.overlaps(enemy.body) &&
          _downStrikeHitIds.add(enemy.id)) {
        _damageEnemy(enemy);
        motor.bounceFromDownStrike();
      }
      if (enemy.alive && enemy.body.overlaps(playerBody)) {
        _damagePlayerFrom(enemy.body, horizontalImpulse: 245);
      }
      for (final projectile in enemy.projectiles) {
        if (!projectile.active || !projectile.body.overlaps(playerBody)) {
          continue;
        }
        projectile.active = false;
        _damagePlayerFrom(
          projectile.body,
          horizontalImpulse: 220,
          verticalImpulse: -180,
        );
      }
    }
    _resolveVoltCombat(playerAttack);
  }

  void _damageEnemy(TiledEnemyActor enemy) {
    if (multiplayer) {
      multiplayerClient?.hitEnemy(enemy.id);
    } else {
      enemy.receiveDamage();
    }
  }

  void _resolveVoltCombat(Aabb? playerAttack) {
    final volt = _volt;
    if (volt == null ||
        session.progress.bossesDefeated.contains('volt') ||
        volt.controller.defeated) {
      return;
    }
    if (playerAttack != null &&
        playerAttack.overlaps(volt.body) &&
        combat.tryHit('volt')) {
      volt.controller.receiveHit();
    }
    if (motor.state == PlayerMotionState.downStriking &&
        motor.body.overlaps(volt.body) &&
        volt.controller.receiveHit()) {
      motor.bounceFromDownStrike();
    }
    if (volt.body.overlaps(motor.body)) {
      _damagePlayerFrom(volt.body, horizontalImpulse: 280);
    }
    for (final hazard in volt.controller.activeHazards(volt.body)) {
      if (hazard.overlaps(motor.body)) {
        _damagePlayerFrom(hazard, horizontalImpulse: 280);
      }
    }
    if (!volt.controller.defeated || _voltVictoryRecorded) return;
    _voltVictoryRecorded = true;
    _setBossEncounter(false);
    unawaited(_persistVoltVictory());
  }

  void _damagePlayerFrom(
    Aabb source, {
    required double horizontalImpulse,
    double verticalImpulse = -260,
  }) {
    if (!combat.receiveDamage()) return;
    final direction = motor.body.left < source.left ? -1.0 : 1.0;
    motor.applyKnockback(Vec2d(horizontalImpulse * direction, verticalImpulse));
  }

  Future<void> _persistVoltVictory() async {
    await session.recordBossDefeated('volt');
    await session.unlockAbility('dash');
  }

  void _resolveHazards() {
    for (final hazard in map.hazards) {
      if (!motor.body.overlaps(hazard) || !combat.receiveDamage()) continue;
      final direction = motor.body.left < hazard.left ? -1.0 : 1.0;
      motor.applyKnockback(Vec2d(220 * direction, -320));
      break;
    }
  }

  void _updateDeath(double dt) {
    final outside = motor.body.top > map.worldHeight + 180;
    if (!combat.isDead && !outside) {
      _deathTimer = 0;
      return;
    }
    _deathTimer += dt;
    if (_deathTimer < 0.8) return;
    _deathTimer = 0;
    combat.restore();
    motor.teleport(_respawnPosition);
    for (final enemy in _enemies) {
      enemy.reset();
    }
    _volt?.reset();
    _voltVictoryRecorded = false;
    _setBossEncounter(false);
  }

  void _updateCamera(double dt) {
    final targetX = motor.body.left + motor.body.width / 2;
    // El jugador queda ligeramente por debajo del centro para anticipar las
    // plataformas y rutas que se encuentran por encima.
    final targetY =
        motor.body.top + motor.body.height / 2 - cameraVerticalOffset;
    final blend = 1 - math.exp(-7 * dt);
    _cameraX += (targetX - _cameraX) * blend;
    _cameraY += (targetY - _cameraY) * blend;
    _publishCamera();
  }

  void _publishCamera() {
    final halfW = viewportWidth / 2;
    final halfH = viewportHeight / 2;
    final maxX = math.max(halfW, map.worldWidth - halfW);
    final maxY = math.max(halfH, map.worldHeight - halfH);
    _cameraX = _cameraX.clamp(halfW, maxX).toDouble();
    _cameraY = _cameraY.clamp(halfH, maxY).toDouble();
    onCameraChanged(_cameraX, _cameraY);
  }

  @override
  void render(Canvas canvas) {
    final visible = Rect.fromLTWH(
      _cameraX - viewportWidth / 2 - 64,
      _cameraY - viewportHeight / 2 - 128,
      viewportWidth + 128,
      viewportHeight + 256,
    );
    canvas.drawRect(visible, _backgroundPaint);
    _drawVisibleTiles(canvas, visible);
    _drawCheckpoints(canvas, visible);
    _drawEnemies(canvas, visible);
    _drawVolt(canvas, visible);
    _drawRemotePlayers(canvas);
    _drawPlayer(canvas);
    _drawLocalPlayerName(canvas);
    _drawHud(canvas);
  }

  void _drawVisibleTiles(Canvas canvas, Rect visible) {
    final minLocalX = (visible.left / map.tileWidth).floor() - 5;
    final maxLocalX = (visible.right / map.tileWidth).ceil() + 5;
    final minLocalY = (visible.top / map.tileHeight).floor() - 5;
    final maxLocalY = (visible.bottom / map.tileHeight).ceil() + 5;
    for (final layer in map.cellsByLayer) {
      for (var localY = minLocalY; localY <= maxLocalY; localY++) {
        final sourceY = localY + map.originCellY;
        if (sourceY < map.originCellY || sourceY > map.maxCellY) continue;
        for (var localX = minLocalX; localX <= maxLocalX; localX++) {
          final sourceX = localX + map.originCellX;
          if (sourceX < map.originCellX || sourceX > map.maxCellX) continue;
          final cell = layer[sourceY * map.mapWidth + sourceX];
          if (cell != null && cell.gid < 19) _drawTile(canvas, cell);
        }
      }
    }
  }

  void _drawTile(Canvas canvas, TiledCell cell) {
    final environment = _environment;
    final x = (cell.x - map.originCellX) * map.tileWidth.toDouble();
    final y = (cell.y - map.originCellY) * map.tileHeight.toDouble();
    if (environment == null) {
      canvas.drawRect(
        Rect.fromLTWH(x, y, 32, 32),
        cell.gid >= 5 && cell.gid <= 7 ? _fallbackHazard : _fallbackSolid,
      );
      return;
    }
    if (map.profile == TiledMapProfile.multiplayer) {
      switch (cell.gid) {
        case 1:
          _drawWholeImage(canvas, environment['tile_normal'], x, y, cell);
        case 2:
          _drawWholeImage(
            canvas,
            environment['platform_support'],
            x,
            y - 84,
            cell,
          );
        case 3:
          _drawWholeImage(canvas, environment['platform_full'], x, y + 5, cell);
        case 4:
          _drawWholeImage(canvas, environment['tube_light'], x, y + 8, cell);
      }
      return;
    }
    switch (cell.gid) {
      case >= 1 && <= 4:
        final index = cell.gid - 1;
        _drawImageRegion(
          canvas,
          environment['wear_scratches'],
          Rect.fromLTWH((index % 2) * 32.0, (index ~/ 2) * 32.0, 32, 32),
          Rect.fromLTWH(x, y, 32, 32),
          cell,
        );
      case >= 5 && <= 7:
        _drawImageRegion(
          canvas,
          environment['spikes_active'],
          Rect.fromLTWH((cell.gid - 5) * 32.0, 0, 32, 32),
          Rect.fromLTWH(x, y, 32, 32),
          cell,
        );
      case 8:
        _drawWholeImage(canvas, environment['platform_full'], x, y + 5, cell);
      case 9:
        _drawWholeImage(
          canvas,
          environment['platform_support'],
          x,
          y - 84,
          cell,
        );
      case 10:
        _drawWholeImage(canvas, environment['tile_normal'], x, y, cell);
      case 11:
        _drawWholeImage(canvas, environment['pipe_tee'], x, y - 26, cell);
      case 12:
        _drawWholeImage(canvas, environment['tube_light'], x, y + 8, cell);
      case 13 || 14:
        _drawImageRegion(
          canvas,
          environment['wear_crack'],
          Rect.fromLTWH((cell.gid - 13) * 32.0, 0, 32, 32),
          Rect.fromLTWH(x, y, 32, 32),
          cell,
        );
      case 15:
        _drawWholeImage(
          canvas,
          environment['control_console'],
          x,
          y - 57,
          cell,
        );
      case 16:
        _drawWholeImage(canvas, environment['door_unlocking'], x, y - 50, cell);
      case 17:
        _drawWholeImage(canvas, environment['arrow_up'], x, y - 19, cell);
      case 18:
        _drawWholeImage(canvas, environment['infra_bridge'], x, y - 29, cell);
      default:
        canvas.drawRect(Rect.fromLTWH(x, y, 32, 32), _fallbackSolid);
    }
  }

  void _drawWholeImage(
    Canvas canvas,
    Image image,
    double x,
    double y,
    TiledCell cell,
  ) {
    _drawImageRegion(
      canvas,
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(x, y, image.width.toDouble(), image.height.toDouble()),
      cell,
    );
  }

  void _drawImageRegion(
    Canvas canvas,
    Image image,
    Rect source,
    Rect destination,
    TiledCell cell,
  ) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.save();
    if (cell.flipHorizontal) {
      canvas.translate(destination.center.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    if (cell.flipVertical) {
      canvas.translate(0, destination.center.dy * 2);
      canvas.scale(1, -1);
    }
    // No hay giros diagonales en el mapa actual. Se conserva el dato al leer
    // el TMX para poder soportarlos si el diseño los incorpora después.
    canvas.drawImageRect(image, source, destination, paint);
    canvas.restore();
  }

  void _drawCheckpoints(Canvas canvas, Rect visible) {
    for (final checkpoint in map.checkpointMarkers) {
      final active = checkpoint.id == _activeCheckpointId;
      final image = _environment
          ?.images[active ? 'checkpoint_active' : 'checkpoint_inactive'];
      if (image == null) {
        final fallback = Aabb(checkpoint.x, checkpoint.y - 38, 51, 70);
        if (visible.overlaps(
          Rect.fromLTWH(
            fallback.left,
            fallback.top,
            fallback.width,
            fallback.height,
          ),
        )) {
          _drawAabb(canvas, fallback, _projectilePaint);
        }
        continue;
      }
      final destination = Rect.fromLTWH(
        checkpoint.x + (51 - image.width) / 2,
        checkpoint.y + 32 - image.height,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      if (!visible.overlaps(destination)) continue;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        destination,
        Paint()..filterQuality = FilterQuality.none,
      );
    }
  }

  void _drawEnemies(Canvas canvas, Rect visible) {
    final sprites = _sprites;
    for (final enemy in _enemies) {
      final renderBounds = Rect.fromLTWH(
        enemy.body.left - 64,
        enemy.body.top - 64,
        enemy.body.width + 128,
        enemy.body.height + 128,
      );
      if (visible.overlaps(renderBounds)) {
        if (sprites == null) {
          _drawAabb(canvas, enemy.body, _enemyPaint);
        } else {
          final sequence = switch (enemy.type) {
            TiledEnemyType.patrol => sprites.patrol[enemy.animation]!,
            TiledEnemyType.watcher => sprites.watcher[enemy.animation]!,
            TiledEnemyType.drone => sprites.drone[enemy.animation]!,
            TiledEnemyType.volt =>
              sprites.volt[enemy.alive ? 'walk' : 'defeat']!,
          };
          final destination = switch (enemy.type) {
            TiledEnemyType.patrol => Rect.fromLTWH(
              enemy.body.left - 45,
              enemy.body.bottom - 76,
              128,
              76,
            ),
            TiledEnemyType.watcher => Rect.fromLTWH(
              enemy.body.left - 27,
              enemy.body.bottom - 104,
              96,
              104,
            ),
            TiledEnemyType.drone => Rect.fromLTWH(
              enemy.body.left - 33,
              enemy.body.top - 24,
              112,
              76,
            ),
            TiledEnemyType.volt => Rect.fromLTWH(
              enemy.body.left - 20,
              enemy.body.bottom - 256,
              192,
              256,
            ),
          };
          _drawSequence(
            canvas,
            sequence,
            destination,
            flip: enemy.direction < 0,
            loop: enemy.alive,
            elapsed: enemy.elapsed,
          );
        }
      }
      for (final projectile in enemy.projectiles) {
        if (!projectile.active) continue;
        final sequence = enemy.type == TiledEnemyType.watcher
            ? sprites?.watcherProjectile['fly']
            : sprites?.droneProjectile['fly'];
        if (sequence == null) {
          _drawAabb(canvas, projectile.body, _projectilePaint);
        } else {
          _drawSequence(
            canvas,
            sequence,
            Rect.fromLTWH(
              projectile.body.left - 11,
              projectile.body.top - 11,
              40,
              32,
            ),
            flip: projectile.velocityX < 0,
          );
        }
      }
    }
  }

  void _drawVolt(Canvas canvas, Rect visible) {
    final volt = _volt;
    if (volt == null || session.progress.bossesDefeated.contains('volt')) {
      return;
    }
    final controller = volt.controller;
    for (final telegraph in controller.telegraphs(volt.body)) {
      _drawEnvironmentEffect(
        canvas,
        'electric_floor_inactive',
        Rect.fromLTWH(telegraph.left, telegraph.top - 24, telegraph.width, 40),
        telegraph,
        _telegraphPaint,
      );
    }
    for (final hazard in controller.activeHazards(volt.body)) {
      _drawEnvironmentEffect(
        canvas,
        'electric_floor_active',
        Rect.fromLTWH(hazard.left, hazard.bottom - 64, hazard.width, 64),
        hazard,
        _fallbackHazard,
      );
    }
    if (!visible.overlaps(
      Rect.fromLTWH(volt.body.left - 100, volt.body.top - 100, 352, 420),
    )) {
      return;
    }
    final sprites = _sprites;
    if (sprites == null) {
      _drawAabb(canvas, volt.body, _enemyPaint);
      return;
    }
    final animation = switch (controller.state) {
      VoltState.intro => 'idle',
      VoltState.chase => 'walk',
      VoltState.slamWindup => 'core_charge',
      VoltState.slamStrike => 'ground_slam',
      VoltState.bombWindup => 'missile_launch',
      VoltState.bombFlight || VoltState.bombImpact => 'idle',
      VoltState.overload => 'vulnerable',
      VoltState.defeated => 'defeat',
    };
    final loops =
        animation == 'idle' || animation == 'walk' || animation == 'vulnerable';
    _drawSequence(
      canvas,
      sprites.volt[animation]!,
      Rect.fromLTWH(volt.body.left - 20, volt.body.bottom - 256, 192, 256),
      flip: volt.facing < 0,
      loop: loops,
      elapsed: controller.stateElapsed,
    );
    if (controller.state == VoltState.bombFlight) {
      final progress = controller.stateProgress;
      final startX = volt.body.left + volt.body.width / 2;
      final missileX = startX + (controller.bombTargetX - startX) * progress;
      final missileY = volt.body.top + 20 + 150 * progress;
      _drawSequence(
        canvas,
        sprites.volt['missile_projectile']!,
        Rect.fromLTWH(missileX - 48, missileY, 96, 64),
        flip: controller.bombTargetX < startX,
        loop: false,
        elapsed: controller.stateElapsed,
      );
    } else if (controller.state == VoltState.bombImpact) {
      _drawSequence(
        canvas,
        sprites.volt['missile_impact']!,
        Rect.fromLTWH(
          controller.bombTargetX - 100,
          volt.body.bottom - 160,
          200,
          160,
        ),
        loop: false,
        elapsed: controller.stateElapsed,
      );
    }
  }

  void _drawEnvironmentEffect(
    Canvas canvas,
    String name,
    Rect destination,
    Aabb fallbackBounds,
    Paint fallbackPaint,
  ) {
    final image = _environment?.images[name];
    if (image == null) {
      _drawAabb(canvas, fallbackBounds, fallbackPaint);
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  void _drawSequence(
    Canvas canvas,
    SpriteSequence sequence,
    Rect destination, {
    bool flip = false,
    bool loop = true,
    double? elapsed,
  }) {
    final image = sequence.frameAt(elapsed ?? _elapsed, loop: loop);
    canvas.save();
    if (flip) {
      canvas.translate(destination.center.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  void _drawPlayer(Canvas canvas) {
    final body = motor.body;
    if (combat.phase == AttackPhase.active) {
      _drawAabb(canvas, combat.attackHitbox(body, motor.facing), _attackPaint);
    }
    final sprites = _sprites;
    if (sprites == null) {
      final paint = combat.isHurt
          ? _hurtPaint
          : motor.state == PlayerMotionState.dashing
          ? _dashPaint
          : _playerPaint;
      _drawAabb(canvas, body, paint);
      return;
    }
    final sequence = sprites.m0[_playerAnimation()]!;
    final image = sequence.frameAt(_elapsed);
    final destination = Rect.fromLTWH(
      body.left + body.width / 2 - 72,
      body.bottom - 88,
      144,
      88,
    );
    canvas.save();
    if (motor.facing < 0) {
      canvas.translate(destination.center.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  void _drawRemotePlayers(Canvas canvas) {
    final client = multiplayerClient;
    final sprites = _sprites;
    if (client == null) return;
    for (final remote in client.remotePlayers.values) {
      final position = _remotePositions[remote.id];
      if (position == null) continue;
      final body = Aabb(
        position.x,
        position.y,
        config.playerWidth,
        config.playerHeight,
      );
      final sequence = sprites?.m0[remote.animation] ?? sprites?.m0['idle'];
      if (sequence == null) {
        _drawAabb(canvas, body, _dashPaint);
      } else {
        _drawSequence(
          canvas,
          sequence,
          Rect.fromLTWH(
            body.left + body.width / 2 - 72,
            body.bottom - 88,
            144,
            88,
          ),
          flip: remote.facing < 0,
          elapsed: _elapsed,
        );
      }
      _playerNamePaint.render(
        canvas,
        remote.name,
        Vector2(body.left - 8, body.top - 70),
      );
    }
  }

  void _drawLocalPlayerName(Canvas canvas) {
    final name = multiplayerClient?.localPlayerName;
    if (name == null) return;
    _playerNamePaint.render(
      canvas,
      name,
      Vector2(motor.body.left - 8, motor.body.top - 70),
    );
  }

  String _playerAnimation() {
    if (combat.isDead) return 'death';
    if (combat.isHurt) return 'hurt';
    if (combat.phase != AttackPhase.idle &&
        motor.state != PlayerMotionState.downStriking) {
      return 'attack';
    }
    return switch (motor.state) {
      PlayerMotionState.grounded =>
        motor.velocity.x.abs() > 20 ? 'run' : 'idle',
      PlayerMotionState.rising => 'rise',
      PlayerMotionState.falling => 'fall',
      PlayerMotionState.wallSliding => 'wall_slide',
      PlayerMotionState.dashing => 'dash',
      PlayerMotionState.downStriking => 'down_strike',
    };
  }

  void _drawHud(Canvas canvas) {
    final left = _cameraX - viewportWidth / (2 * cameraZoom);
    final top = _cameraY - viewportHeight / (2 * cameraZoom);
    for (var i = 0; i < combat.maxHealth; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          left + hudSafeInsetX + i * 30,
          top + hudSafeInsetY,
          22,
          14,
        ),
        Paint()
          ..color = i < combat.health
              ? const Color(0xFF55DFEF)
              : const Color(0xFF263944),
      );
    }
    _smallPaint.render(
      canvas,
      multiplayer ? 'ARENA MULTIJUGADOR' : 'SECTOR DE ENERGÍA',
      Vector2(left + hudSafeInsetX, top + hudSafeInsetY + 26),
    );
    if (_messageTimer > 0) {
      _smallPaint.render(
        canvas,
        _message,
        Vector2(left + 410, top + hudSafeInsetY + 26),
      );
    }
    final volt = _volt;
    if (_bossEncounterActive && volt != null) {
      canvas.drawRect(
        Rect.fromLTWH(left + 340, top + 25, 600, 16),
        Paint()..color = const Color(0xFF342A26),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          left + 340,
          top + 25,
          600 * volt.controller.healthRatio,
          16,
        ),
        _fallbackHazard,
      );
      _smallPaint.render(
        canvas,
        'VOLT  FASE ${volt.controller.secondPhase ? 2 : 1}',
        Vector2(left + 500, top + 48),
      );
    }
  }

  void _drawAabb(Canvas canvas, Aabb box, Paint paint) {
    canvas.drawRect(
      Rect.fromLTWH(box.left, box.top, box.width, box.height),
      paint,
    );
  }
}
