import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/domain/combat/combat_controller.dart';
import 'package:game_final/domain/config/gameplay_config.dart';

void main() {
  const config = GameplayConfig();

  test('an attack damages the same target only once per activation', () {
    final combat = CombatController(config: config);
    expect(combat.startAttack(), isTrue);
    combat.update(config.attackStartup + 0.001);

    expect(combat.phase, AttackPhase.active);
    expect(combat.tryHit('enemy'), isTrue);
    expect(combat.tryHit('enemy'), isFalse);
    expect(combat.tryHit('other'), isTrue);
  });

  test('invulnerability rejects repeated damage', () {
    final combat = CombatController(config: config);

    expect(combat.receiveDamage(), isTrue);
    expect(combat.health, 2);
    expect(combat.receiveDamage(), isFalse);
    expect(combat.health, 2);

    combat.update(config.hurtInvulnerability + 0.01);
    expect(combat.receiveDamage(), isTrue);
    expect(combat.health, 1);
  });
}
