import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/domain/config/gameplay_config.dart';
import 'package:game_final/domain/input/input_controller.dart';
import 'package:game_final/domain/movement/aabb.dart';
import 'package:game_final/domain/movement/player_motor.dart';

void main() {
  const config = GameplayConfig();
  const floor = Aabb(0, 200, 800, 40);

  PlayerInputFrame input({
    double horizontal = 0,
    bool jumpHeld = false,
    bool jumpPressed = false,
    bool dashPressed = false,
  }) => PlayerInputFrame(
    horizontal: horizontal,
    downHeld: false,
    jumpHeld: jumpHeld,
    jumpPressed: jumpPressed,
    attackPressed: false,
    dashPressed: dashPressed,
  );

  test('lands on a solid without crossing it', () {
    final motor = PlayerMotor(
      config: config,
      initialPosition: const Vec2d(100, 100),
    );
    for (var i = 0; i < 120; i++) {
      motor.update(1 / 60, input(), const [floor]);
    }
    expect(motor.grounded, isTrue);
    expect(motor.body.bottom, closeTo(floor.top, 0.001));
  });

  test('jump buffer triggers when landing', () {
    final motor = PlayerMotor(
      config: config,
      initialPosition: const Vec2d(100, 145),
    );
    motor.update(1 / 60, input(jumpPressed: true, jumpHeld: true), const [
      floor,
    ]);
    for (var i = 0; i < 8; i++) {
      motor.update(1 / 60, input(jumpHeld: true), const [floor]);
    }
    expect(motor.velocity.y, lessThan(0));
    expect(motor.grounded, isFalse);
  });

  test('held jump reaches higher than released jump', () {
    double peak({required bool held}) {
      final motor = PlayerMotor(
        config: config,
        initialPosition: const Vec2d(100, 158),
      );
      motor.update(1 / 60, input(), const [floor]);
      motor.update(1 / 60, input(jumpPressed: true, jumpHeld: held), const [
        floor,
      ]);
      var top = motor.position.y;
      for (var i = 0; i < 60; i++) {
        motor.update(1 / 60, input(jumpHeld: held), const [floor]);
        if (motor.position.y < top) top = motor.position.y;
      }
      return top;
    }

    expect(peak(held: true), lessThan(peak(held: false)));
  });

  test('15 percent jump boost reaches a platform 115 pixels higher', () {
    const elevatedPlatform = Aabb(50, 85, 200, 12);
    final motor = PlayerMotor(
      config: config,
      initialPosition: const Vec2d(100, 158),
    );
    motor.update(1 / 60, input(), const [floor]);
    motor.update(
      1 / 60,
      input(jumpPressed: true, jumpHeld: true),
      const [floor],
      oneWayPlatforms: const [elevatedPlatform],
    );
    for (var i = 0; i < 120 && !motor.grounded; i++) {
      motor.update(
        1 / 60,
        input(jumpHeld: true),
        const [floor],
        oneWayPlatforms: const [elevatedPlatform],
      );
    }

    expect(motor.grounded, isTrue);
    expect(motor.body.bottom, closeTo(elevatedPlatform.top, 0.001));
  });

  test('double jump is consumed once while airborne', () {
    final motor = PlayerMotor(
      config: config,
      initialPosition: const Vec2d(100, 158),
    );
    motor.update(1 / 60, input(), const [floor]);
    motor.update(1 / 60, input(jumpPressed: true, jumpHeld: true), const [
      floor,
    ]);
    for (var i = 0; i < 8; i++) {
      motor.update(1 / 60, input(jumpHeld: true), const [floor]);
    }
    motor.update(1 / 60, input(jumpPressed: true, jumpHeld: true), const [
      floor,
    ]);
    final velocityAfterDoubleJump = motor.velocity.y;
    motor.update(1 / 60, input(jumpPressed: true), const [floor]);

    expect(velocityAfterDoubleJump, lessThan(-400));
    expect(motor.canDoubleJump, isFalse);
  });

  test('one-way platform is ignored from below and catches a fall', () {
    const platform = Aabb(50, 130, 200, 12);
    final motor = PlayerMotor(
      config: config,
      initialPosition: const Vec2d(100, 145),
    );
    motor.velocity = const Vec2d(0, -520);
    var wentAbove = false;
    for (var i = 0; i < 50; i++) {
      motor.update(
        1 / 60,
        input(jumpHeld: true),
        const [],
        oneWayPlatforms: const [platform],
      );
      wentAbove = wentAbove || motor.body.bottom < platform.top;
      if (motor.velocity.y > 0 && wentAbove) break;
    }
    expect(wentAbove, isTrue);
    for (var i = 0; i < 90; i++) {
      motor.update(
        1 / 60,
        input(),
        const [],
        oneWayPlatforms: const [platform],
      );
      if (motor.grounded) break;
    }
    expect(motor.grounded, isTrue);
    expect(motor.body.bottom, closeTo(platform.top, 0.001));
  });
}
