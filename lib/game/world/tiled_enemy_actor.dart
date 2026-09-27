import 'dart:math' as math;

import '../../domain/bosses/volt_controller.dart';
import '../../domain/movement/aabb.dart';
import 'tiled_map_data.dart';

class TiledEnemyProjectile {
  TiledEnemyProjectile({
    required this.x,
    required this.y,
    required this.velocityX,
  });

  double x;
  double y;
  final double velocityX;
  bool active = true;

  Aabb get body => Aabb(x, y, 18, 10);

  void update(double dt, List<Aabb> solids) {
    x += velocityX * dt;
    if (solids.any(body.overlaps)) active = false;
  }
}

class TiledEnemyActor {
  TiledEnemyActor({
    required this.id,
    required this.type,
    required this.markerX,
    required this.markerY,
    this.spawnX,
    this.spawnY,
    this.maxHealth = 3,
  }) : health = maxHealth {
    _resetPosition();
  }

  final String id;
  final TiledEnemyType type;
  final double markerX;
  final double markerY;
  final double? spawnX;
  final double? spawnY;
  final int maxHealth;
  final List<TiledEnemyProjectile> projectiles = [];

  late double x;
  late double y;
  double velocityX = 0;
  double velocityY = 0;
  double elapsed = 0;
  double attackTimer = 0;
  double hurtTimer = 0;
  double _shootCooldown = 0.7;
  int direction = -1;
  int health;
  bool grounded = false;

  double get width => switch (type) {
    TiledEnemyType.drone => 46,
    TiledEnemyType.patrol => 38,
    TiledEnemyType.watcher => 42,
    TiledEnemyType.volt => 152,
  };

  double get height => switch (type) {
    TiledEnemyType.drone => 32,
    TiledEnemyType.patrol => 38,
    TiledEnemyType.watcher => 60,
    TiledEnemyType.volt => 220,
  };

  double get markerImageWidth => switch (type) {
    TiledEnemyType.drone => 75,
    TiledEnemyType.patrol => 94,
    TiledEnemyType.watcher => 67,
    TiledEnemyType.volt => 187,
  };

  bool get alive => health > 0;
  Aabb get body => Aabb(x, y, width, height);

  String get animation {
    if (!alive) {
      return type == TiledEnemyType.watcher ? 'cooldown' : 'death';
    }
    if (hurtTimer > 0) {
      return type == TiledEnemyType.watcher ? 'cooldown' : 'hurt';
    }
    if (attackTimer > 0) {
      return type == TiledEnemyType.patrol ? 'attack' : 'shoot';
    }
    return switch (type) {
      TiledEnemyType.patrol => velocityX.abs() > 1 ? 'walk' : 'idle',
      TiledEnemyType.watcher => _shootCooldown < 0.5 ? 'aim' : 'idle',
      TiledEnemyType.drone => 'patrol',
      TiledEnemyType.volt => 'idle',
    };
  }

  void update(
    double dt,
    Aabb player,
    List<Aabb> solids,
    List<Aabb> oneWayPlatforms,
  ) {
    elapsed += dt;
    attackTimer = math.max(0, attackTimer - dt);
    hurtTimer = math.max(0, hurtTimer - dt);
    for (final projectile in projectiles) {
      projectile.update(dt, solids);
    }
    projectiles.removeWhere((projectile) => !projectile.active);
    if (!alive) return;

    final playerCenter = player.left + player.width / 2;
    final center = body.left + body.width / 2;
    if ((playerCenter - center).abs() < 760) {
      direction = playerCenter < center ? -1 : 1;
    }

    switch (type) {
      case TiledEnemyType.patrol:
        if ((playerCenter - center).abs() < 68) {
          velocityX = 0;
          attackTimer = 0.25;
        } else {
          velocityX = 72 * direction.toDouble();
        }
        _moveGrounded(dt, solids, oneWayPlatforms, patrolEdges: true);
      case TiledEnemyType.watcher:
        velocityX = 0;
        _moveGrounded(dt, solids, oneWayPlatforms);
        _tryShoot(dt, player, interval: 1.8, range: 760);
      case TiledEnemyType.drone:
        _updateDrone(dt, solids, oneWayPlatforms);
        _tryShoot(dt, player, interval: 2.1, range: 680);
      case TiledEnemyType.volt:
        if ((playerCenter - center).abs() < 92) {
          velocityX = 0;
          attackTimer = 0.3;
        } else {
          velocityX = 54 * direction.toDouble();
        }
        _moveGrounded(dt, solids, oneWayPlatforms, patrolEdges: true);
    }
  }

  void _moveGrounded(
    double dt,
    List<Aabb> solids,
    List<Aabb> oneWayPlatforms, {
    bool patrolEdges = false,
  }) {
    velocityY = math.min(780, velocityY + 1800 * dt);
    final wallHit = _moveHorizontal(dt, solids);
    _moveVertical(dt, solids, oneWayPlatforms);
    if (wallHit) direction *= -1;
    if (patrolEdges && grounded && !_hasGroundAhead(solids, oneWayPlatforms)) {
      direction *= -1;
    }
  }

  void _updateDrone(double dt, List<Aabb> solids, List<Aabb> oneWayPlatforms) {
    velocityX = 82 * direction.toDouble();
    final flightAnchorY = spawnY ?? markerY - height + 32;
    final desiredY = flightAnchorY + math.sin(elapsed * 1.4) * 54;
    velocityY = (desiredY - y).clamp(-105.0, 105.0).toDouble();
    if (_moveHorizontal(dt, solids)) direction *= -1;
    _moveVertical(dt, solids, oneWayPlatforms, gravityBody: false);
  }

  bool _moveHorizontal(double dt, List<Aabb> solids) {
    if (velocityX == 0) return false;
    x += velocityX * dt;
    for (final solid in solids) {
      if (!body.overlaps(solid)) continue;
      x = velocityX > 0 ? solid.left - width : solid.right;
      velocityX = 0;
      return true;
    }
    return false;
  }

  void _moveVertical(
    double dt,
    List<Aabb> solids,
    List<Aabb> oneWayPlatforms, {
    bool gravityBody = true,
  }) {
    final previousBottom = body.bottom;
    grounded = false;
    y += velocityY * dt;
    for (final solid in solids) {
      if (!body.overlaps(solid)) continue;
      if (velocityY >= 0) {
        y = solid.top - height;
        grounded = gravityBody;
      } else {
        y = solid.bottom;
      }
      velocityY = 0;
    }
    if (velocityY < 0) return;
    for (final platform in oneWayPlatforms) {
      if (previousBottom > platform.top + 2 || !body.overlaps(platform)) {
        continue;
      }
      y = platform.top - height;
      velocityY = 0;
      grounded = gravityBody;
    }
  }

  bool _hasGroundAhead(List<Aabb> solids, List<Aabb> oneWayPlatforms) {
    final probeX = direction > 0 ? body.right + 2 : body.left - 6;
    final probe = Aabb(probeX, body.bottom, 4, 10);
    return solids.any(probe.overlaps) || oneWayPlatforms.any(probe.overlaps);
  }

  void _tryShoot(
    double dt,
    Aabb player, {
    required double interval,
    required double range,
  }) {
    _shootCooldown -= dt;
    final dx = player.left + player.width / 2 - (body.left + body.width / 2);
    if (_shootCooldown > 0 || dx.abs() > range) return;
    _shootCooldown = interval;
    attackTimer = 0.35;
    direction = dx < 0 ? -1 : 1;
    projectiles.add(
      TiledEnemyProjectile(
        x: direction > 0 ? body.right : body.left - 18,
        y: body.top + body.height * 0.38,
        velocityX: 300 * direction.toDouble(),
      ),
    );
  }

  void receiveDamage() {
    if (!alive) return;
    health -= 1;
    elapsed = 0;
    hurtTimer = 0.24;
    direction *= -1;
  }

  void setNetworkHealth(int value) {
    final next = value.clamp(0, maxHealth);
    if (next < health) {
      elapsed = 0;
      hurtTimer = 0.24;
    }
    health = next;
  }

  void reset() {
    health = maxHealth;
    direction = -1;
    velocityX = 0;
    velocityY = 0;
    elapsed = 0;
    attackTimer = 0;
    hurtTimer = 0;
    _shootCooldown = 0.7;
    projectiles.clear();
    _resetPosition();
  }

  void _resetPosition() {
    x = spawnX ?? markerX + (markerImageWidth - width) / 2;
    y = spawnY ?? markerY + 32 - height;
  }
}

class TiledVoltActor {
  TiledVoltActor({required this.markerX, required this.markerY}) {
    reset();
  }

  final double markerX;
  final double markerY;
  final VoltController controller = VoltController();
  late double x;
  late double y;
  double velocityY = 0;
  double previousGap = 1000;
  bool retreatArmed = false;
  int facing = 1;
  bool grounded = false;

  Aabb get body => Aabb(x, y, 152, 220);
  bool get active => !controller.defeated;

  bool update(
    double dt,
    Aabb player,
    List<Aabb> solids,
    List<Aabb> oneWayPlatforms,
    double worldWidth,
    Aabb encounterZone,
  ) {
    final playerCenter = player.left + player.width / 2;
    final voltCenter = body.left + body.width / 2;
    if (!encounterZone.overlaps(player)) {
      _applyGravity(dt, solids, oneWayPlatforms);
      return false;
    }

    controller.update(dt);
    final signedDistance = playerCenter - voltCenter;
    if (signedDistance.abs() > 2) facing = signedDistance.sign.toInt();
    final gap = player.left > body.right
        ? player.left - body.right
        : body.left > player.right
        ? body.left - player.right
        : 0.0;
    if (gap <= 110) retreatArmed = true;
    final retreatSpeed = (gap - previousGap) / dt;
    final retreatingFast = retreatArmed && retreatSpeed >= 260;
    final startedAttack = controller.tryStartAttack(
      playerGap: gap,
      retreatingFast: retreatingFast,
      targetX: playerCenter,
      direction: facing,
      minTargetX: 0,
      maxTargetX: worldWidth,
    );
    if (startedAttack) {
      retreatArmed = false;
    } else if (controller.chasing && gap > 30) {
      final speed = controller.secondPhase ? 132.0 : 104.0;
      _moveHorizontal(facing * speed * dt, solids);
    }
    if (gap > 220) retreatArmed = false;
    previousGap = gap;
    _applyGravity(dt, solids, oneWayPlatforms);
    return true;
  }

  void _moveHorizontal(double delta, List<Aabb> solids) {
    x += delta;
    for (final solid in solids) {
      if (!body.overlaps(solid)) continue;
      x = delta > 0 ? solid.left - body.width : solid.right;
    }
  }

  void _applyGravity(double dt, List<Aabb> solids, List<Aabb> oneWayPlatforms) {
    final previousBottom = body.bottom;
    velocityY = math.min(780, velocityY + 1800 * dt);
    y += velocityY * dt;
    grounded = false;
    for (final solid in solids) {
      if (!body.overlaps(solid)) continue;
      if (velocityY >= 0) {
        y = solid.top - body.height;
        grounded = true;
      } else {
        y = solid.bottom;
      }
      velocityY = 0;
    }
    if (velocityY < 0) return;
    for (final platform in oneWayPlatforms) {
      if (previousBottom > platform.top + 2 || !body.overlaps(platform)) {
        continue;
      }
      y = platform.top - body.height;
      velocityY = 0;
      grounded = true;
    }
  }

  void reset() {
    controller.reset();
    x = markerX + (187 - 152) / 2;
    y = markerY + 32 - 220;
    velocityY = 0;
    previousGap = 1000;
    retreatArmed = false;
    facing = 1;
    grounded = false;
  }
}
