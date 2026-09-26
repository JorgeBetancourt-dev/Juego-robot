import 'dart:math' as math;

import '../config/gameplay_config.dart';
import '../input/input_controller.dart';
import 'aabb.dart';

enum PlayerMotionState {
  grounded,
  rising,
  falling,
  wallSliding,
  dashing,
  downStriking,
}

class MovementAbilities {
  const MovementAbilities({
    required this.dash,
    required this.wallJump,
    required this.downStrike,
    required this.doubleJump,
  });

  const MovementAbilities.all()
    : dash = true,
      wallJump = true,
      downStrike = true,
      doubleJump = true;

  final bool dash;
  final bool wallJump;
  final bool downStrike;
  final bool doubleJump;
}

class PlayerMotor {
  PlayerMotor({
    required this.config,
    Vec2d initialPosition = const Vec2d(120, 500),
  }) : position = initialPosition;

  final GameplayConfig config;
  Vec2d position;
  Vec2d velocity = const Vec2d(0, 0);
  bool grounded = false;
  int wallContact = 0;
  int facing = 1;
  PlayerMotionState state = PlayerMotionState.falling;

  double _timeSinceGrounded = double.infinity;
  double _jumpBufferRemaining = 0;
  double _dashRemaining = 0;
  double _dashCooldownRemaining = 0;
  bool _airDashAvailable = true;
  bool _doubleJumpAvailable = false;
  bool _downStriking = false;

  Aabb get body =>
      Aabb(position.x, position.y, config.playerWidth, config.playerHeight);

  bool get canAirDash => _airDashAvailable;
  bool get canDoubleJump => _doubleJumpAvailable;

  void update(
    double rawDt,
    PlayerInputFrame input,
    List<Aabb> solids, {
    List<Aabb> oneWayPlatforms = const [],
    MovementAbilities abilities = const MovementAbilities.all(),
  }) {
    final dt = math.min(rawDt, 0.05);
    _dashCooldownRemaining = math.max(0, _dashCooldownRemaining - dt);

    if (grounded) {
      _timeSinceGrounded = 0;
      _airDashAvailable = true;
      _doubleJumpAvailable = true;
      _downStriking = false;
    } else {
      _timeSinceGrounded += dt;
    }

    if (input.jumpPressed) {
      _jumpBufferRemaining = config.jumpBuffer;
    } else {
      _jumpBufferRemaining = math.max(0, _jumpBufferRemaining - dt);
    }

    if (abilities.downStrike &&
        input.attackPressed &&
        input.downHeld &&
        !grounded) {
      _downStriking = true;
      _dashRemaining = 0;
      velocity = Vec2d(0, config.downStrikeSpeed);
    }

    if (!_downStriking &&
        abilities.dash &&
        input.dashPressed &&
        _dashCooldownRemaining <= 0 &&
        (grounded || _airDashAvailable)) {
      _dashRemaining = config.dashDuration;
      _dashCooldownRemaining = config.dashDuration + config.dashCooldown;
      _airDashAvailable = false;
      final direction = input.horizontal == 0
          ? facing.toDouble()
          : input.horizontal;
      facing = direction < 0 ? -1 : 1;
      velocity = Vec2d(config.dashSpeed * facing, 0);
    }

    if (_downStriking) {
      velocity = Vec2d(0, config.downStrikeSpeed);
      state = PlayerMotionState.downStriking;
    } else if (_dashRemaining > 0) {
      _dashRemaining = math.max(0, _dashRemaining - dt);
      state = PlayerMotionState.dashing;
    } else {
      _updateStandardMovement(dt, input, abilities);
    }

    _moveHorizontal(dt, solids);
    _moveVertical(dt, solids, oneWayPlatforms);
    _refreshState(input);
  }

  void _updateStandardMovement(
    double dt,
    PlayerInputFrame input,
    MovementAbilities abilities,
  ) {
    if (input.horizontal != 0) facing = input.horizontal < 0 ? -1 : 1;
    final target = input.horizontal * config.maxRunSpeed;
    final acceleration = grounded
        ? (input.horizontal == 0
              ? config.groundDeceleration
              : config.groundAcceleration)
        : config.airAcceleration;
    final nextX = _approach(velocity.x, target, acceleration * dt);

    if (_jumpBufferRemaining > 0) {
      if (grounded || _timeSinceGrounded <= config.coyoteTime) {
        _performJump(nextX, -config.jumpSpeed);
        return;
      }
      if (abilities.wallJump && wallContact != 0) {
        facing = -wallContact;
        _performJump(-wallContact * config.wallJumpX, -config.wallJumpY);
        return;
      }
      if (abilities.doubleJump && _doubleJumpAvailable) {
        _doubleJumpAvailable = false;
        _performJump(nextX, -config.jumpSpeed);
        return;
      }
    }

    var gravity = velocity.y < 0 && input.jumpHeld
        ? config.gravityRise
        : config.gravityFall;
    if (velocity.y < 0 && !input.jumpHeld) gravity *= 1.65;
    var nextY = math.min(config.maxFallSpeed, velocity.y + gravity * dt);
    final pressingIntoWall =
        wallContact != 0 &&
        input.horizontal != 0 &&
        input.horizontal.sign == wallContact.toDouble();
    if (pressingIntoWall && nextY > config.wallSlideSpeed) {
      nextY = config.wallSlideSpeed;
    }
    velocity = Vec2d(nextX, nextY);
  }

  void _performJump(double x, double y) {
    velocity = Vec2d(x, y);
    grounded = false;
    _timeSinceGrounded = double.infinity;
    _jumpBufferRemaining = 0;
  }

  void _moveHorizontal(double dt, List<Aabb> solids) {
    wallContact = 0;
    if (velocity.x == 0) return;
    position = position.copyWith(x: position.x + velocity.x * dt);
    for (final solid in solids) {
      if (!body.overlaps(solid)) continue;
      wallContact = velocity.x > 0 ? 1 : -1;
      position = position.copyWith(
        x: velocity.x > 0 ? solid.left - config.playerWidth : solid.right,
      );
      velocity = velocity.copyWith(x: 0);
    }
  }

  void _moveVertical(double dt, List<Aabb> solids, List<Aabb> oneWayPlatforms) {
    final previousBottom = body.bottom;
    grounded = false;
    position = position.copyWith(y: position.y + velocity.y * dt);
    for (final solid in solids) {
      if (!body.overlaps(solid)) continue;
      if (velocity.y >= 0) {
        position = position.copyWith(y: solid.top - config.playerHeight);
        grounded = true;
        _downStriking = false;
      } else {
        position = position.copyWith(y: solid.bottom);
      }
      velocity = velocity.copyWith(y: 0);
    }
    if (velocity.y < 0) return;
    for (final platform in oneWayPlatforms) {
      if (previousBottom > platform.top + 2 || !body.overlaps(platform)) {
        continue;
      }
      position = position.copyWith(y: platform.top - config.playerHeight);
      velocity = velocity.copyWith(y: 0);
      grounded = true;
      _downStriking = false;
    }
  }

  void bounceFromDownStrike() {
    _downStriking = false;
    _airDashAvailable = true;
    velocity = Vec2d(velocity.x, -config.jumpSpeed * 0.72);
  }

  void applyKnockback(Vec2d impulse) {
    _dashRemaining = 0;
    _downStriking = false;
    velocity = impulse;
  }

  void teleport(Vec2d target) {
    position = target;
    velocity = const Vec2d(0, 0);
    grounded = false;
    wallContact = 0;
    _dashRemaining = 0;
    _downStriking = false;
  }

  void _refreshState(PlayerInputFrame input) {
    if (_downStriking) {
      state = PlayerMotionState.downStriking;
    } else if (_dashRemaining > 0) {
      state = PlayerMotionState.dashing;
    } else if (grounded) {
      state = PlayerMotionState.grounded;
    } else if (wallContact != 0 &&
        velocity.y >= 0 &&
        input.horizontal.sign == wallContact.toDouble()) {
      state = PlayerMotionState.wallSliding;
    } else if (velocity.y < 0) {
      state = PlayerMotionState.rising;
    } else {
      state = PlayerMotionState.falling;
    }
  }

  double _approach(double current, double target, double amount) {
    if (current < target) return math.min(current + amount, target);
    if (current > target) return math.max(current - amount, target);
    return target;
  }
}
