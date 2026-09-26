import 'dart:math' as math;

import '../config/gameplay_config.dart';
import '../movement/aabb.dart';

enum AttackPhase { idle, startup, active, recovery }

class CombatController {
  CombatController({required this.config, this.maxHealth = 3})
    : health = maxHealth;

  final GameplayConfig config;
  final int maxHealth;
  int health;
  AttackPhase phase = AttackPhase.idle;
  double _phaseRemaining = 0;
  double _invulnerabilityRemaining = 0;
  double _hurtRemaining = 0;
  final Set<String> _damagedThisAttack = {};

  bool get isInvulnerable => _invulnerabilityRemaining > 0;
  bool get isHurt => _hurtRemaining > 0;
  bool get isDead => health <= 0;
  bool get canControl => !isHurt && !isDead;
  double get healthRatio => health / maxHealth;

  void update(double dt) {
    _invulnerabilityRemaining = math.max(0, _invulnerabilityRemaining - dt);
    _hurtRemaining = math.max(0, _hurtRemaining - dt);
    if (phase == AttackPhase.idle) return;
    _phaseRemaining -= dt;
    if (_phaseRemaining > 0) return;
    switch (phase) {
      case AttackPhase.startup:
        phase = AttackPhase.active;
        _phaseRemaining = config.attackActive;
      case AttackPhase.active:
        phase = AttackPhase.recovery;
        _phaseRemaining = config.attackRecovery;
      case AttackPhase.recovery:
        phase = AttackPhase.idle;
        _damagedThisAttack.clear();
      case AttackPhase.idle:
        break;
    }
  }

  bool startAttack() {
    if (phase != AttackPhase.idle || !canControl) return false;
    phase = AttackPhase.startup;
    _phaseRemaining = config.attackStartup;
    _damagedThisAttack.clear();
    return true;
  }

  bool tryHit(String targetId) {
    if (phase != AttackPhase.active || _damagedThisAttack.contains(targetId)) {
      return false;
    }
    _damagedThisAttack.add(targetId);
    return true;
  }

  bool receiveDamage() {
    if (isInvulnerable || isDead) return false;
    health -= 1;
    _invulnerabilityRemaining = config.hurtInvulnerability;
    _hurtRemaining = config.hurtStun;
    phase = AttackPhase.idle;
    _damagedThisAttack.clear();
    return true;
  }

  void restore() {
    health = maxHealth;
    _invulnerabilityRemaining = 0;
    _hurtRemaining = 0;
    phase = AttackPhase.idle;
    _damagedThisAttack.clear();
  }

  Aabb attackHitbox(Aabb playerBody, int facing) {
    const width = 46.0;
    const height = 32.0;
    final left = facing > 0 ? playerBody.right : playerBody.left - width;
    return Aabb(left, playerBody.top + 5, width, height);
  }
}
