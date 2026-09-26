import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/domain/bosses/volt_controller.dart';
import 'package:game_final/domain/movement/aabb.dart';

void main() {
  const body = Aabb(564, 430, 152, 220);

  void advanceUntil(VoltController volt, bool Function() condition) {
    for (var i = 0; i < 1000 && !condition(); i++) {
      volt.update(0.05);
    }
  }

  void beginSlam(VoltController volt) {
    advanceUntil(volt, () => volt.chasing);
    expect(
      volt.tryStartAttack(
        playerGap: 30,
        retreatingFast: false,
        targetX: 780,
        direction: 1,
      ),
      isTrue,
    );
  }

  void beginBombs(VoltController volt) {
    advanceUntil(volt, () => volt.chasing);
    expect(volt.nextAttack, VoltAttack.bombs);
    expect(
      volt.tryStartAttack(
        playerGap: 80,
        retreatingFast: true,
        targetX: 420,
        direction: -1,
      ),
      isTrue,
    );
  }

  test('VOLT chases before attacking and telegraphs the close strike', () {
    final volt = VoltController();
    advanceUntil(volt, () => volt.chasing);

    expect(
      volt.tryStartAttack(
        playerGap: 31,
        retreatingFast: false,
        targetX: 800,
        direction: 1,
      ),
      isFalse,
    );
    beginSlam(volt);
    expect(volt.telegraphs(body), isNotEmpty);
    expect(volt.activeHazards(body), isEmpty);

    advanceUntil(volt, () => volt.activeHazards(body).isNotEmpty);
    expect(volt.activeHazards(body), isNotEmpty);
  });

  test('VOLT alternates close strike and bombs', () {
    final volt = VoltController();
    beginSlam(volt);
    advanceUntil(volt, () => volt.chasing);
    expect(volt.nextAttack, VoltAttack.bombs);

    expect(
      volt.tryStartAttack(
        playerGap: 90,
        retreatingFast: false,
        targetX: 400,
        direction: -1,
      ),
      isFalse,
    );
    beginBombs(volt);
    expect(volt.bombTargetX, 420);
    expect(volt.nextAttack, VoltAttack.closeSlam);
  });

  test('VOLT only receives one hit during each overload', () {
    final volt = VoltController();
    beginSlam(volt);
    advanceUntil(volt, () => volt.chasing);
    beginBombs(volt);
    advanceUntil(volt, () => volt.vulnerable);

    expect(volt.receiveHit(), isTrue);
    expect(volt.receiveHit(), isFalse);
    expect(volt.health, volt.maxHealth - 1);
  });

  test('VOLT enters phase two below half health', () {
    final volt = VoltController(maxHealth: 4);
    for (var hit = 0; hit < 2; hit++) {
      beginSlam(volt);
      advanceUntil(volt, () => volt.chasing);
      beginBombs(volt);
      advanceUntil(volt, () => volt.vulnerable);
      expect(volt.receiveHit(), isTrue);
      volt.update(2);
    }

    expect(volt.secondPhase, isTrue);
  });
}
