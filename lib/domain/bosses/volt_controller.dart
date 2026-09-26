import '../movement/aabb.dart';

enum VoltAttack { closeSlam, bombs }

enum VoltState {
  intro,
  chase,
  slamWindup,
  slamStrike,
  bombWindup,
  bombFlight,
  bombImpact,
  overload,
  defeated,
}

class VoltController {
  VoltController({this.maxHealth = 12}) : health = maxHealth;

  final int maxHealth;
  int health;
  VoltState state = VoltState.intro;
  VoltAttack _nextAttack = VoltAttack.closeSlam;
  double _remaining = 0.8;
  double _stateDuration = 0.8;
  double _chaseElapsed = 0;
  int _attacksSinceOverload = 0;
  bool _hitDuringCurrentOverload = false;

  int attackDirection = 1;
  double bombTargetX = 640;

  bool get defeated => state == VoltState.defeated;
  bool get vulnerable => state == VoltState.overload;
  bool get chasing => state == VoltState.chase;
  bool get secondPhase => health <= maxHealth ~/ 2;
  VoltAttack get nextAttack => _nextAttack;
  double get healthRatio => health / maxHealth;
  double get stateProgress => _stateDuration <= 0
      ? 1
      : (1 - (_remaining / _stateDuration)).clamp(0.0, 1.0);
  double get stateElapsed => state == VoltState.chase
      ? _chaseElapsed
      : (_stateDuration - _remaining).clamp(0.0, _stateDuration);

  void update(double dt) {
    if (defeated) return;
    if (state == VoltState.chase) {
      _chaseElapsed += dt;
      return;
    }

    _remaining -= dt;
    if (_remaining > 0) return;
    switch (state) {
      case VoltState.intro:
      case VoltState.overload:
        _startChase();
      case VoltState.slamWindup:
        _setState(VoltState.slamStrike, secondPhase ? 0.82 : 0.92);
      case VoltState.slamStrike:
        _finishAttack();
      case VoltState.bombWindup:
        _setState(VoltState.bombFlight, secondPhase ? 0.5 : 0.65);
      case VoltState.bombFlight:
        _setState(VoltState.bombImpact, secondPhase ? 0.42 : 0.5);
      case VoltState.bombImpact:
        _finishAttack();
      case VoltState.chase:
      case VoltState.defeated:
        break;
    }
  }

  bool tryStartAttack({
    required double playerGap,
    required bool retreatingFast,
    required double targetX,
    required int direction,
    double minTargetX = 90,
    double maxTargetX = 1190,
  }) {
    if (!chasing || defeated) return false;
    attackDirection = direction == 0 ? attackDirection : direction.sign;

    switch (_nextAttack) {
      case VoltAttack.closeSlam:
        if (playerGap > 30) return false;
        _nextAttack = VoltAttack.bombs;
        _setState(VoltState.slamWindup, secondPhase ? 0.62 : 0.72);
      case VoltAttack.bombs:
        // Retreat is the intended trigger. The short close-range fallback keeps
        // the fight progressing if M0 stays underneath Volt indefinitely.
        if (!retreatingFast && !(playerGap <= 30 && _chaseElapsed >= 0.65)) {
          return false;
        }
        bombTargetX = targetX.clamp(minTargetX, maxTargetX).toDouble();
        _nextAttack = VoltAttack.closeSlam;
        _setState(VoltState.bombWindup, secondPhase ? 0.42 : 0.55);
    }
    return true;
  }

  bool receiveHit() {
    if (!vulnerable || _hitDuringCurrentOverload || defeated) return false;
    _hitDuringCurrentOverload = true;
    health -= 1;
    if (health <= 0) {
      health = 0;
      state = VoltState.defeated;
      _remaining = 0;
    }
    return true;
  }

  List<Aabb> activeHazards(Aabb voltBody) => switch (state) {
    VoltState.slamStrike => [
      Aabb(
        attackDirection > 0 ? voltBody.right - 8 : voltBody.left - 132,
        voltBody.bottom - 54,
        140,
        54,
      ),
    ],
    VoltState.bombImpact => [
      Aabb(bombTargetX - 62, voltBody.bottom - 70, 124, 70),
    ],
    _ => const [],
  };

  List<Aabb> telegraphs(Aabb voltBody) => switch (state) {
    VoltState.slamWindup => [
      Aabb(
        attackDirection > 0 ? voltBody.right - 8 : voltBody.left - 132,
        voltBody.bottom - 10,
        140,
        10,
      ),
    ],
    VoltState.bombFlight => [
      Aabb(bombTargetX - 62, voltBody.bottom - 10, 124, 10),
    ],
    _ => const [],
  };

  void _finishAttack() {
    _attacksSinceOverload += 1;
    if (_attacksSinceOverload >= 2) {
      _attacksSinceOverload = 0;
      _hitDuringCurrentOverload = false;
      _setState(VoltState.overload, secondPhase ? 1.25 : 1.7);
    } else {
      _startChase();
    }
  }

  void _startChase() {
    state = VoltState.chase;
    _remaining = 0;
    _stateDuration = 0;
    _chaseElapsed = 0;
  }

  void _setState(VoltState next, double duration) {
    state = next;
    _remaining = duration;
    _stateDuration = duration;
  }

  void reset() {
    health = maxHealth;
    state = VoltState.intro;
    _nextAttack = VoltAttack.closeSlam;
    _remaining = 0.8;
    _stateDuration = 0.8;
    _chaseElapsed = 0;
    _attacksSinceOverload = 0;
    _hitDuringCurrentOverload = false;
    attackDirection = 1;
    bombTargetX = 640;
  }
}
