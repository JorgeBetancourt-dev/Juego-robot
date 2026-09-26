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
import '../../domain/world/room_catalog.dart';
import '../../domain/world/room_definition.dart';
import '../art/environment_assets.dart';
import '../art/sprite_assets.dart';

class PlaygroundWorld extends Component {
  PlaygroundWorld({
    required this.input,
    required this.config,
    required this.playground,
    required this.voltChallenge,
    required this.session,
    required this.onBossMusicChanged,
  });

  final InputController input;
  final GameplayConfig config;
  final bool playground;
  final bool voltChallenge;
  final GameSession session;
  final void Function(bool active) onBossMusicChanged;
  late final PlayerMotor motor;
  late final CombatController combat;
  late RoomDefinition room;

  final _enemy = _PatrolEnemy();
  final _watcher = _WatcherEnemy();
  final _drone = _DroneEnemy();
  final _volt = VoltController();
  GameSpriteAssets? _sprites;
  EnvironmentAssets? _environment;
  double _elapsed = 0;
  double _movingX = 560;
  double _deathTimer = 0;
  double _messageTimer = 0;
  String _message = '';
  bool _checkpointActivated = false;
  double _voltX = 564;
  double _previousVoltGap = 1000;
  bool _voltRetreatArmed = false;
  int _voltFacing = 1;

  final Paint _backgroundPaint = Paint()..color = const Color(0xFF0A151D);
  final Paint _gridPaint = Paint()
    ..color = const Color(0xFF112936)
    ..strokeWidth = 1;
  final Paint _solidPaint = Paint()..color = const Color(0xFF4D5960);
  final Paint _oneWayPaint = Paint()..color = const Color(0xFF9AA9B0);
  final Paint _movingPaint = Paint()..color = const Color(0xFF367EA6);
  final Paint _edgePaint = Paint()
    ..color = const Color(0xFF8A9AA3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _playerPaint = Paint()..color = const Color(0xFF55DFEF);
  final Paint _dashPaint = Paint()..color = const Color(0xFFB776FF);
  final Paint _hurtPaint = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _enemyPaint = Paint()..color = const Color(0xFFFF973D);
  final Paint _watcherPaint = Paint()..color = const Color(0xFFFFB15C);
  final Paint _dronePaint = Paint()..color = const Color(0xFFFF7B45);
  final Paint _projectilePaint = Paint()..color = const Color(0xFFFFE15C);
  final Paint _hazardPaint = Paint()..color = const Color(0xFFE64242);
  final Paint _attackPaint = Paint()..color = const Color(0x66FF3939);
  final Paint _checkpointPaint = Paint()..color = const Color(0xFF42FFE1);
  final Paint _gatePaint = Paint()..color = const Color(0xFF153D66);
  final Paint _switchOffPaint = Paint()..color = const Color(0xFF6D7331);
  final Paint _switchOnPaint = Paint()..color = const Color(0xFF52E36B);
  final Paint _secretPaint = Paint()..color = const Color(0xFFB05CFF);
  final Paint _breakablePaint = Paint()..color = const Color(0xFF7B536E);
  final Paint _voltPaint = Paint()..color = const Color(0xFFFFC436);
  final Paint _telegraphPaint = Paint()..color = const Color(0x99FFE04A);
  late final TextPaint _labelPaint;
  late final TextPaint _smallPaint;

  Aabb get _movingPlatform => Aabb(_movingX, 500, 140, 20);
  Aabb get _switchBody => const Aabb(650, 610, 34, 40);
  // The visual canvas is 192x256. The collision volume intentionally excludes
  // antennas, sparks and attack effects while covering Volt's torso and limbs.
  Aabb get _voltBody => Aabb(_voltX, 430, 152, 220);
  String get _breakableFlag => '${room.id}_breakable';
  bool get _voltActive =>
      room.hasVolt && !session.progress.bossesDefeated.contains('volt');

  List<Aabb> get _roomSolids => [
    ...room.solids,
    if (room.breakableBarrier != null &&
        !session.progress.worldFlags.contains(_breakableFlag))
      room.breakableBarrier!,
  ];

  MovementAbilities get _abilities {
    if (playground) return const MovementAbilities.all();
    if (voltChallenge) {
      return const MovementAbilities(
        dash: false,
        wallJump: false,
        downStrike: false,
        doubleJump: false,
      );
    }
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
    room = RoomCatalog.byId(
      playground ? 'energy_e10_high_voltage' : session.progress.roomId,
    );
    motor = PlayerMotor(config: config, initialPosition: room.spawn);
    combat = CombatController(config: config);
    _labelPaint = TextPaint(
      style: const flutter.TextStyle(
        color: Color(0xFF9FC0D0),
        fontSize: 18,
        fontFamily: 'monospace',
      ),
    );
    _smallPaint = TextPaint(
      style: const flutter.TextStyle(
        color: Color(0xFFBBD5E0),
        fontSize: 14,
        fontFamily: 'monospace',
      ),
    );
    _sprites = await GameSpriteAssets.load();
    _environment = await EnvironmentAssets.load();
    _applyRoomRewards();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final safeDt = math.min(dt, 0.05);
    _elapsed += safeDt;
    _messageTimer = math.max(0, _messageTimer - safeDt);
    _updateMovingPlatform();

    combat.update(safeDt);
    final frame = input.consumeFrame();
    final wasDownStriking =
        motor.state == PlayerMotionState.downStriking ||
        (frame.attackPressed && frame.downHeld && !motor.grounded);
    if (frame.attackPressed && !frame.downHeld) combat.startAttack();
    final movementFrame = combat.canControl ? frame : _blockedFrame();
    motor.update(
      safeDt,
      movementFrame,
      [..._roomSolids, if (room.hasMovingPlatform) _movingPlatform],
      oneWayPlatforms: room.oneWayPlatforms,
      abilities: _abilities,
    );
    _updateBreakable(wasDownStriking);

    if (room.hasPatrol) {
      _enemy.update(safeDt);
      _resolveCombat();
    }
    if (room.hasWatcher) {
      _watcher.update(safeDt, motor.body);
      _resolveWatcherCombat();
    }
    if (room.hasDrone) {
      _drone.update(safeDt);
      _resolveDroneCombat();
    }
    if (_voltActive) {
      _updateVolt(safeDt);
      _resolveVoltCombat();
    }
    _resolveHazards();
    _updateSwitch();
    _updateCheckpoint();
    _updateSecret();
    _updateDeath(safeDt);
    _updateRoomTransition();
  }

  void _updateVolt(double dt) {
    _volt.update(dt);
    if (!_volt.chasing) return;

    final body = _voltBody;
    final playerCenter = motor.body.left + motor.body.width / 2;
    final voltCenter = body.left + body.width / 2;
    final signedDistance = playerCenter - voltCenter;
    if (signedDistance.abs() > 2) _voltFacing = signedDistance.sign.toInt();

    final gap = motor.body.left > body.right
        ? motor.body.left - body.right
        : body.left > motor.body.right
        ? body.left - motor.body.right
        : 0.0;
    if (gap <= 110) _voltRetreatArmed = true;
    final retreatSpeed = (gap - _previousVoltGap) / dt;
    final retreatingFast = _voltRetreatArmed && retreatSpeed >= 260;

    final startedAttack = _volt.tryStartAttack(
      playerGap: gap,
      retreatingFast: retreatingFast,
      targetX: playerCenter,
      direction: _voltFacing,
    );
    if (startedAttack) {
      _voltRetreatArmed = false;
    } else if (gap > 30) {
      final speed = _volt.secondPhase ? 132.0 : 104.0;
      _voltX = (_voltX + _voltFacing * speed * dt)
          .clamp(36.0, 1092.0)
          .toDouble();
    }
    if (gap > 220) _voltRetreatArmed = false;
    _previousVoltGap = gap;
  }

  void _updateMovingPlatform() {
    if (!room.hasMovingPlatform) return;
    final oldPlatform = _movingPlatform;
    final nextX = 560 + math.sin(_elapsed * 1.25) * 180;
    final delta = nextX - _movingX;
    if (_standingOn(motor.body, oldPlatform)) {
      motor.position = motor.position.copyWith(x: motor.position.x + delta);
    }
    _movingX = nextX;
  }

  PlayerInputFrame _blockedFrame() => const PlayerInputFrame(
    horizontal: 0,
    downHeld: false,
    jumpHeld: false,
    jumpPressed: false,
    attackPressed: false,
    dashPressed: false,
  );

  bool _standingOn(Aabb body, Aabb platform) =>
      (body.bottom - platform.top).abs() < 2 &&
      body.right > platform.left &&
      body.left < platform.right;

  void _resolveCombat() {
    if (!_enemy.alive) return;
    if (combat.phase == AttackPhase.active) {
      final hitbox = combat.attackHitbox(motor.body, motor.facing);
      if (hitbox.overlaps(_enemy.body) && combat.tryHit(_enemy.id)) {
        _enemy.receiveDamage();
      }
    }
    if (motor.state == PlayerMotionState.downStriking &&
        motor.body.overlaps(_enemy.body)) {
      _enemy.receiveDamage();
      motor.bounceFromDownStrike();
    }
    if (_enemy.body.overlaps(motor.body) && combat.receiveDamage()) {
      final direction = motor.body.left < _enemy.body.left ? -1.0 : 1.0;
      motor.applyKnockback(Vec2d(260 * direction, -260));
    }
  }

  void _resolveWatcherCombat() {
    if (_watcher.alive && combat.phase == AttackPhase.active) {
      final hitbox = combat.attackHitbox(motor.body, motor.facing);
      if (hitbox.overlaps(_watcher.body) && combat.tryHit(_watcher.id)) {
        _watcher.receiveDamage();
      }
    }
    for (final projectile in _watcher.projectiles) {
      if (!projectile.active || !projectile.body.overlaps(motor.body)) continue;
      projectile.active = false;
      if (combat.receiveDamage()) {
        final direction = projectile.velocityX < 0 ? -1.0 : 1.0;
        motor.applyKnockback(Vec2d(220 * direction, -180));
      }
    }
  }

  void _resolveDroneCombat() {
    if (!_drone.alive) return;
    if (combat.phase == AttackPhase.active) {
      final hitbox = combat.attackHitbox(motor.body, motor.facing);
      if (hitbox.overlaps(_drone.body) && combat.tryHit(_drone.id)) {
        _drone.receiveDamage();
      }
    }
    if (_drone.body.overlaps(motor.body) && combat.receiveDamage()) {
      final direction = motor.body.left < _drone.body.left ? -1.0 : 1.0;
      motor.applyKnockback(Vec2d(240 * direction, -240));
    }
  }

  void _resolveHazards() {
    for (final hazard in room.hazards) {
      if (!motor.body.overlaps(hazard) || !combat.receiveDamage()) continue;
      final direction = motor.body.left < hazard.left ? -1.0 : 1.0;
      motor.applyKnockback(Vec2d(220 * direction, -320));
    }
  }

  void _updateBreakable(bool wasDownStriking) {
    final barrier = room.breakableBarrier;
    if (!wasDownStriking ||
        barrier == null ||
        session.progress.worldFlags.contains(_breakableFlag)) {
      return;
    }
    final landedOnBarrier =
        (motor.body.bottom - barrier.top).abs() < 3 &&
        motor.body.right > barrier.left &&
        motor.body.left < barrier.right;
    if (!landedOnBarrier) return;
    _showMessage('BARRERA FRACTURADA');
    unawaited(session.setWorldFlag(_breakableFlag));
  }

  void _resolveVoltCombat() {
    if (combat.phase == AttackPhase.active) {
      final hitbox = combat.attackHitbox(motor.body, motor.facing);
      if (hitbox.overlaps(_voltBody) && combat.tryHit('volt')) {
        _volt.receiveHit();
      }
    }
    if (motor.state == PlayerMotionState.downStriking &&
        motor.body.overlaps(_voltBody) &&
        _volt.receiveHit()) {
      motor.bounceFromDownStrike();
    }
    for (final hazard in _volt.activeHazards(_voltBody)) {
      if (hazard.overlaps(motor.body) && combat.receiveDamage()) {
        final direction = motor.body.left < 640 ? -1.0 : 1.0;
        motor.applyKnockback(Vec2d(280 * direction, -300));
      }
    }
    if (!_volt.defeated) return;
    _showMessage('VOLT DESACTIVADO  MÓDULO DASH INSTALADO');
    unawaited(_persistVoltVictory());
  }

  Future<void> _persistVoltVictory() async {
    if (session.progress.bossesDefeated.contains('volt')) return;
    await session.recordBossDefeated('volt');
    await session.unlockAbility('dash');
    onBossMusicChanged(false);
  }

  void _updateSwitch() {
    if (!room.hasSwitch || !_switchBody.overlaps(motor.body)) return;
    if (!session.progress.worldFlags.contains(room.switchFlag)) {
      _showMessage(room.switchMessage);
      unawaited(session.setWorldFlag(room.switchFlag));
    }
  }

  void _updateCheckpoint() {
    if (room.checkpointId == null ||
        _checkpointActivated ||
        motor.body.left > 155) {
      return;
    }
    _checkpointActivated = true;
    combat.restore();
    _showMessage('CHECKPOINT SINCRONIZADO');
    unawaited(session.activateCheckpoint(room.checkpointId!, room.id));
  }

  void _updateSecret() {
    final secretId = room.secretId;
    if (secretId == null ||
        session.progress.secretsFound.contains(secretId) ||
        motor.body.top > 320) {
      return;
    }
    _showMessage('REGISTRO SECRETO RECUPERADO');
    unawaited(session.recordSecret(secretId));
  }

  void _updateDeath(double dt) {
    if (!combat.isDead && motor.position.y <= 780) return;
    _deathTimer += dt;
    if (_deathTimer < 0.8) return;
    _deathTimer = 0;
    combat.restore();
    motor.teleport(room.spawn);
    _enemy.reset();
    _watcher.reset();
    _drone.reset();
    _volt.reset();
    _resetVoltPosition();
  }

  void _updateRoomTransition() {
    final ExitSide? side = motor.body.left > 1270
        ? ExitSide.right
        : motor.body.right < 10
        ? ExitSide.left
        : motor.body.top > 710
        ? ExitSide.bottom
        : motor.body.top < 0
        ? ExitSide.top
        : null;
    if (side == null) return;
    if (voltChallenge) {
      _showMessage('ARENA DE PRUEBA BLOQUEADA');
      _returnInside(side);
      return;
    }
    final exits = room.exits.where((exit) => exit.side == side);
    if (exits.isEmpty) {
      _returnInside(side);
      return;
    }
    final exit = exits.first;
    final requirement = exit.requirement;
    if (requirement != null && !requirement.isMet(session.progress)) {
      _showMessage('ACCESO DENEGADO  REQUIERE ${requirement.label}');
      _returnInside(side);
      return;
    }
    _enterRoom(exit.targetRoomId, exit.targetSpawn);
  }

  void _returnInside(ExitSide side) {
    switch (side) {
      case ExitSide.left:
        motor.teleport(Vec2d(32, motor.position.y));
      case ExitSide.right:
        motor.teleport(Vec2d(1220, motor.position.y));
      case ExitSide.top:
        motor.teleport(Vec2d(motor.position.x.clamp(32, 1220).toDouble(), 32));
      case ExitSide.bottom:
        motor.teleport(room.spawn);
    }
  }

  void _enterRoom(String roomId, Vec2d spawn) {
    room = RoomCatalog.byId(roomId);
    onBossMusicChanged(
      room.hasVolt && !session.progress.bossesDefeated.contains('volt'),
    );
    motor.teleport(spawn);
    combat.restore();
    _enemy.reset();
    _watcher.reset();
    _drone.reset();
    _volt.reset();
    _resetVoltPosition();
    _checkpointActivated = false;
    _movingX = 560;
    _showMessage(room.displayName);
    _applyRoomRewards();
  }

  void _resetVoltPosition() {
    _voltX = 564;
    _previousVoltGap = 1000;
    _voltRetreatArmed = false;
    _voltFacing = 1;
  }

  void _applyRoomRewards() {
    if (playground) return;
    final newAbilities = room.abilityPickups
        .where((ability) => !session.progress.abilities.contains(ability))
        .toList();
    if (newAbilities.isNotEmpty) {
      _showMessage(
        'MÓDULOS ${newAbilities.join(' ').toUpperCase()} INSTALADOS',
      );
      unawaited(session.unlockAbilities(newAbilities));
    }
    final permission = room.permissionPickup;
    if (permission != null &&
        !session.progress.permissions.contains(permission)) {
      _showMessage('PERMISO ${permission.toUpperCase()} CONCEDIDO');
      unawaited(session.grantPermission(permission));
    }
  }

  void _showMessage(String value) {
    _message = value;
    _messageTimer = 2.2;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1280, 720), _backgroundPaint);
    _drawEnvironmentBackdrop(canvas);
    _drawGrid(canvas);
    _drawEnvironmentDecorations(canvas);
    for (final solid in room.solids) {
      _drawEnvironmentSolid(canvas, solid, 'tile_normal', _solidPaint);
    }
    final breakable = room.breakableBarrier;
    if (breakable != null &&
        !session.progress.worldFlags.contains(_breakableFlag)) {
      _drawEnvironmentSolid(canvas, breakable, 'tile_worn', _breakablePaint);
    }
    for (final platform in room.oneWayPlatforms) {
      _drawEnvironmentImage(
        canvas,
        'platform_full',
        Rect.fromLTWH(
          platform.left,
          platform.top - 8,
          platform.width,
          math.max(32, platform.height + 8),
        ),
        fallback: () => _drawAabb(canvas, platform, _oneWayPaint),
      );
    }
    if (room.hasMovingPlatform) {
      _drawEnvironmentImage(
        canvas,
        'moving_platform_center',
        Rect.fromLTWH(
          _movingPlatform.left,
          _movingPlatform.top - 18,
          _movingPlatform.width,
          48,
        ),
        fallback: () =>
            _drawAabb(canvas, _movingPlatform, _movingPaint, outline: true),
      );
    }
    for (final hazard in room.hazards) {
      _drawEnvironmentHazard(canvas, hazard);
    }
    _drawInteractives(canvas);
    _drawRoomHeader(canvas);
    _drawHud(canvas);
    if (room.hasPatrol) _drawEnemy(canvas);
    if (room.hasWatcher) _drawWatcher(canvas);
    if (room.hasDrone) _drawDrone(canvas);
    if (_voltActive) _drawVolt(canvas);
    _drawPlayer(canvas);
  }

  void _drawGrid(Canvas canvas) {
    for (double x = 0; x <= 1280; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, 720), _gridPaint);
    }
    for (double y = 0; y <= 720; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(1280, y), _gridPaint);
    }
  }

  void _drawEnvironmentBackdrop(Canvas canvas) {
    final environment = _environment;
    if (environment == null) return;
    _drawUiImage(
      canvas,
      environment['background_far'],
      const Rect.fromLTWH(0, 208, 1280, 512),
      opacity: 0.9,
    );
    _drawUiImage(
      canvas,
      environment['background_mid'],
      const Rect.fromLTWH(0, 330, 1280, 390),
      opacity: 0.34,
    );
  }

  void _drawEnvironmentDecorations(Canvas canvas) {
    final environment = _environment;
    if (environment == null) return;
    final variant = room.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
    _drawUiImage(
      canvas,
      environment[variant.isEven ? 'generator_main' : 'energy_core'],
      const Rect.fromLTWH(1010, 390, 128, 240),
      opacity: 0.52,
    );
    _drawUiImage(
      canvas,
      environment['active_cables'],
      const Rect.fromLTWH(760, 76, 250, 156),
      opacity: 0.55,
    );
    _drawUiImage(
      canvas,
      environment[variant % 3 == 0 ? 'sign_warning' : 'sign_energy'],
      const Rect.fromLTWH(170, 150, 144, 88),
      opacity: 0.82,
    );
    _drawUiImage(
      canvas,
      environment[variant % 3 == 1 ? 'sign_sector' : 'sign_direction'],
      const Rect.fromLTWH(1060, 150, 112, 88),
      opacity: 0.78,
    );
    _drawUiImage(
      canvas,
      environment['industrial_lamp'],
      const Rect.fromLTWH(580, 92, 96, 72),
      opacity: 0.72,
    );
  }

  void _drawEnvironmentSolid(
    Canvas canvas,
    Aabb solid,
    String texture,
    Paint fallbackPaint,
  ) {
    final environment = _environment;
    if (environment == null) {
      _drawAabb(canvas, solid, fallbackPaint, outline: true);
      return;
    }
    final image = environment[texture];
    final clip = Rect.fromLTWH(
      solid.left,
      solid.top,
      solid.width,
      solid.height,
    );
    canvas.save();
    canvas.clipRect(clip);
    for (double y = solid.top; y < solid.bottom; y += 32) {
      for (double x = solid.left; x < solid.right; x += 32) {
        _drawUiImage(canvas, image, Rect.fromLTWH(x, y, 32, 32));
      }
    }
    canvas.restore();
    canvas.drawRect(clip, _edgePaint);
  }

  void _drawEnvironmentHazard(Canvas canvas, Aabb hazard) {
    _drawEnvironmentImage(
      canvas,
      'spikes_active',
      Rect.fromLTWH(
        hazard.left - 20,
        hazard.bottom - 64,
        hazard.width + 40,
        64,
      ),
      fallback: () => _drawAabb(canvas, hazard, _hazardPaint),
    );
  }

  void _drawEnvironmentImage(
    Canvas canvas,
    String name,
    Rect destination, {
    bool flip = false,
    required void Function() fallback,
  }) {
    final environment = _environment;
    if (environment == null) {
      fallback();
      return;
    }
    _drawUiImage(canvas, environment[name], destination, flip: flip);
  }

  void _drawUiImage(
    Canvas canvas,
    Image image,
    Rect destination, {
    bool flip = false,
    double opacity = 1,
  }) {
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.save();
    if (flip) {
      canvas.translate(destination.center.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(image, source, destination, paint);
    canvas.restore();
  }

  void _drawInteractives(Canvas canvas) {
    if (room.checkpointId != null) {
      _drawEnvironmentImage(
        canvas,
        _checkpointActivated ? 'checkpoint_active' : 'checkpoint_inactive',
        const Rect.fromLTWH(38, 522, 88, 128),
        fallback: () => canvas.drawRect(
          const Rect.fromLTWH(78, 520, 12, 130),
          _checkpointPaint,
        ),
      );
    }
    if (room.hasSwitch) {
      final active = session.progress.worldFlags.contains(room.switchFlag);
      _drawEnvironmentImage(
        canvas,
        active ? 'switch_active' : 'switch_inactive',
        Rect.fromLTWH(_switchBody.left - 15, _switchBody.bottom - 64, 64, 64),
        fallback: () => _drawAabb(
          canvas,
          _switchBody,
          active ? _switchOnPaint : _switchOffPaint,
        ),
      );
    }
    if (room.secretId != null) {
      _drawEnvironmentImage(
        canvas,
        'collectible_rotate',
        const Rect.fromLTWH(1071, 207, 64, 72),
        fallback: () => canvas.drawRect(
          const Rect.fromLTWH(1080, 220, 46, 46),
          _secretPaint,
        ),
      );
    }
    for (final exit in room.exits) {
      final requirement = exit.requirement;
      if (requirement == null || requirement.isMet(session.progress)) continue;
      if (exit.side == ExitSide.top || exit.side == ExitSide.bottom) {
        final top = exit.side == ExitSide.top ? 0.0 : 626.0;
        canvas.drawRect(Rect.fromLTWH(530, top, 220, 24), _gatePaint);
        continue;
      }
      final left = exit.side == ExitSide.left ? 0.0 : 1200.0;
      _drawEnvironmentImage(
        canvas,
        'door_blocked',
        Rect.fromLTWH(left, 538, 80, 112),
        flip: exit.side == ExitSide.left,
        fallback: () => canvas.drawRect(
          Rect.fromLTWH(exit.side == ExitSide.left ? 4 : 1248, 470, 28, 180),
          _gatePaint,
        ),
      );
    }
  }

  void _drawRoomHeader(Canvas canvas) {
    _labelPaint.render(canvas, room.displayName, Vector2(50, 42));
    final controls = <String>['SPACE salto', 'J ataque'];
    if (_abilities.dash) controls.add('K dash');
    if (_abilities.downStrike) controls.add('S+J descendente');
    _smallPaint.render(canvas, controls.join('  •  '), Vector2(50, 70));
    if (playground) {
      _labelPaint.render(canvas, 'MODO PLAYGROUND', Vector2(1040, 42));
    }
    if (voltChallenge) {
      _labelPaint.render(canvas, 'PRUEBA CONTRA VOLT', Vector2(1010, 42));
    }
    if (_messageTimer > 0) {
      _labelPaint.render(canvas, _message, Vector2(360, 145));
    }
  }

  void _drawHud(Canvas canvas) {
    for (var i = 0; i < combat.maxHealth; i++) {
      final paint = Paint()
        ..color = i < combat.health
            ? const Color(0xFF55DFEF)
            : const Color(0xFF263944);
      canvas.drawRect(Rect.fromLTWH(50 + i * 30, 94, 22, 14), paint);
    }
    final modules = [
      if (_abilities.dash) 'DASH',
      if (_abilities.wallJump) 'WALL',
      if (_abilities.downStrike) 'DOWN',
      if (_abilities.doubleJump) 'DOUBLE',
    ].join(' ');
    _smallPaint.render(
      canvas,
      'MÓDULOS ${modules.isEmpty ? 'NINGUNO' : modules}',
      Vector2(50, 118),
    );
  }

  void _drawEnemy(Canvas canvas) {
    if (!_enemy.alive) return;
    final sprites = _sprites;
    if (sprites == null) {
      _drawAabb(canvas, _enemy.body, _enemyPaint, outline: true);
    } else {
      _drawSequence(
        canvas,
        sprites.patrol['walk']!,
        Rect.fromLTWH(_enemy.x - 45, _enemy.body.bottom - 76, 128, 76),
        flip: _enemy.direction < 0,
      );
    }
    _smallPaint.render(
      canvas,
      'PATROL ${_enemy.health}',
      Vector2(_enemy.x - 12, _enemy.y - 22),
    );
  }

  void _drawWatcher(Canvas canvas) {
    if (_watcher.alive) {
      final sprites = _sprites;
      if (sprites == null) {
        _drawAabb(canvas, _watcher.body, _watcherPaint, outline: true);
      } else {
        final animation = _watcher.cooldown < 0.28
            ? 'shoot'
            : _watcher.cooldown < 0.62
            ? 'aim'
            : 'idle';
        _drawSequence(
          canvas,
          sprites.watcher[animation]!,
          Rect.fromLTWH(
            _watcher.body.left - 27,
            _watcher.body.bottom - 104,
            96,
            104,
          ),
          flip: _watcher.direction < 0,
        );
      }
      _smallPaint.render(
        canvas,
        'WATCHER ${_watcher.health}',
        Vector2(_watcher.x - 20, _watcher.y - 22),
      );
    }
    for (final projectile in _watcher.projectiles) {
      if (projectile.active) {
        final projectileSprites = _sprites?.watcherProjectile['fly'];
        if (projectileSprites == null) {
          _drawAabb(canvas, projectile.body, _projectilePaint);
        } else {
          _drawSequence(
            canvas,
            projectileSprites,
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

  void _drawDrone(Canvas canvas) {
    if (!_drone.alive) return;
    final sprites = _sprites;
    if (sprites == null) {
      _drawAabb(canvas, _drone.body, _dronePaint, outline: true);
    } else {
      _drawSequence(
        canvas,
        sprites.drone['patrol']!,
        Rect.fromLTWH(_drone.body.left - 33, _drone.body.top - 24, 112, 76),
        flip: math.cos(_elapsed * 1.1) < 0,
      );
    }
    _smallPaint.render(
      canvas,
      'DRONE ${_drone.health}',
      Vector2(_drone.x - 12, _drone.y - 20),
    );
  }

  void _drawVolt(Canvas canvas) {
    for (final telegraph in _volt.telegraphs(_voltBody)) {
      _drawEnvironmentImage(
        canvas,
        'electric_floor_inactive',
        Rect.fromLTWH(telegraph.left, telegraph.top - 24, telegraph.width, 40),
        fallback: () => _drawAabb(canvas, telegraph, _telegraphPaint),
      );
    }
    for (final hazard in _volt.activeHazards(_voltBody)) {
      _drawEnvironmentImage(
        canvas,
        'electric_floor_active',
        Rect.fromLTWH(hazard.left, hazard.bottom - 64, hazard.width, 64),
        fallback: () => _drawAabb(canvas, hazard, _hazardPaint),
      );
    }
    final sprites = _sprites;
    if (sprites == null) {
      _drawAabb(
        canvas,
        _voltBody,
        _volt.vulnerable ? _hurtPaint : _voltPaint,
        outline: true,
      );
    } else {
      final animation = switch (_volt.state) {
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
          animation == 'idle' ||
          animation == 'walk' ||
          animation == 'vulnerable';
      _drawSequence(
        canvas,
        sprites.volt[animation]!,
        Rect.fromLTWH(_voltBody.left - 20, _voltBody.bottom - 256, 192, 256),
        flip: _voltFacing < 0,
        loop: loops,
        elapsed: _volt.stateElapsed,
      );
      if (_volt.state == VoltState.bombFlight) {
        final progress = _volt.stateProgress;
        final startX = _voltBody.left + _voltBody.width / 2;
        final missileX = startX + (_volt.bombTargetX - startX) * progress;
        final missileY = 430 + 150 * progress;
        _drawSequence(
          canvas,
          sprites.volt['missile_projectile']!,
          Rect.fromLTWH(missileX - 48, missileY, 96, 64),
          flip: _volt.bombTargetX < startX,
          loop: false,
          elapsed: _volt.stateElapsed,
        );
      } else if (_volt.state == VoltState.bombImpact) {
        _drawSequence(
          canvas,
          sprites.volt['missile_impact']!,
          Rect.fromLTWH(_volt.bombTargetX - 100, 490, 200, 160),
          loop: false,
          elapsed: _volt.stateElapsed,
        );
      }
    }
    canvas.drawRect(
      const Rect.fromLTWH(340, 25, 600, 16),
      Paint()..color = const Color(0xFF342A26),
    );
    canvas.drawRect(
      Rect.fromLTWH(340, 25, 600 * _volt.healthRatio, 16),
      _hazardPaint,
    );
    _smallPaint.render(
      canvas,
      'VOLT  FASE ${_volt.secondPhase ? 2 : 1}  ${_volt.state.name.toUpperCase()}',
      Vector2(500, 48),
    );
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
      final centerY = body.top + body.height / 2;
      final startX = motor.facing > 0 ? body.right - 5 : body.left + 5;
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(startX + 14 * motor.facing, centerY),
        Paint()
          ..color = const Color(0xFF071017)
          ..strokeWidth = 3,
      );
      return;
    }
    final animation = _playerAnimation();
    _drawSequence(
      canvas,
      sprites.m0[animation]!,
      Rect.fromLTWH(body.left + body.width / 2 - 72, body.bottom - 88, 144, 88),
      flip: motor.facing < 0,
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

  void _drawSequence(
    Canvas canvas,
    SpriteSequence sequence,
    Rect destination, {
    bool flip = false,
    bool loop = true,
    double? elapsed,
  }) {
    final image = sequence.frameAt(elapsed ?? _elapsed, loop: loop);
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.save();
    if (flip) {
      canvas.translate(destination.center.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(image, source, destination, Paint());
    canvas.restore();
  }

  void _drawAabb(Canvas canvas, Aabb box, Paint paint, {bool outline = false}) {
    final rect = Rect.fromLTWH(box.left, box.top, box.width, box.height);
    canvas.drawRect(rect, paint);
    if (outline) canvas.drawRect(rect, _edgePaint);
  }
}

class _PatrolEnemy {
  final String id = 'patrol_01';
  double x = 600;
  final double y = 612;
  int health = 3;
  int direction = 1;

  bool get alive => health > 0;
  Aabb get body => Aabb(x, y, 38, 38);

  void update(double dt) {
    if (!alive) return;
    x += direction * 72 * dt;
    if (x < 520) {
      x = 520;
      direction = 1;
    } else if (x > 780) {
      x = 780;
      direction = -1;
    }
  }

  void receiveDamage() {
    if (!alive) return;
    health -= 1;
    direction *= -1;
  }

  void reset() {
    x = 600;
    health = 3;
    direction = 1;
  }
}

class _WatcherEnemy {
  final String id = 'watcher_01';
  final double x = 970;
  final double y = 590;
  int health = 3;
  int direction = -1;
  double _cooldown = 0.8;
  final List<_Projectile> projectiles = [];

  bool get alive => health > 0;
  double get cooldown => _cooldown;
  Aabb get body => Aabb(x, y, 42, 60);

  void update(double dt, Aabb target) {
    for (final projectile in projectiles) {
      projectile.update(dt);
    }
    projectiles.removeWhere(
      (projectile) =>
          !projectile.active || projectile.x < -40 || projectile.x > 1320,
    );
    if (!alive) return;
    direction = target.left < x ? -1 : 1;
    _cooldown -= dt;
    if (_cooldown > 0) return;
    _cooldown = 1.8;
    projectiles.add(_Projectile(x + 18, y + 18, 300.0 * direction));
  }

  void receiveDamage() {
    if (alive) health -= 1;
  }

  void reset() {
    health = 3;
    direction = -1;
    _cooldown = 0.8;
    projectiles.clear();
  }
}

class _Projectile {
  _Projectile(this.x, this.y, this.velocityX);

  double x;
  final double y;
  final double velocityX;
  bool active = true;

  Aabb get body => Aabb(x, y, 18, 10);

  void update(double dt) => x += velocityX * dt;
}

class _DroneEnemy {
  final String id = 'drone_01';
  double x = 620;
  double y = 360;
  int health = 3;
  double _elapsed = 0;

  bool get alive => health > 0;
  Aabb get body => Aabb(x, y, 46, 32);

  void update(double dt) {
    if (!alive) return;
    _elapsed += dt;
    x = 620 + math.sin(_elapsed * 1.1) * 210;
    y = 360 + math.sin(_elapsed * 2.0) * 70;
  }

  void receiveDamage() {
    if (alive) health -= 1;
  }

  void reset() {
    x = 620;
    y = 360;
    health = 3;
    _elapsed = 0;
  }
}
