import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/domain/progression/game_progress.dart';

void main() {
  test('progress survives a JSON-compatible round trip', () {
    final original = GameProgress(
      checkpointId: 'energy_cp_02',
      roomId: 'energy_generator_01',
      abilities: const {'dash', 'wallJump'},
      bossesDefeated: const {'volt'},
    );

    final restored = GameProgress.fromJson(original.toJson());

    expect(restored.checkpointId, original.checkpointId);
    expect(restored.roomId, original.roomId);
    expect(restored.abilities, original.abilities);
    expect(restored.bossesDefeated, original.bossesDefeated);
  });

  test('rejects saves created by a newer schema', () {
    expect(
      () => GameProgress.fromJson(const {'schemaVersion': 999}),
      throwsFormatException,
    );
  });

  test('migrates old saves without leaking advanced prototype abilities', () {
    final migrated = GameProgress.fromJson(const {
      'schemaVersion': 1,
      'roomId': 'energy_ability_lab_09',
      'abilities': ['dash', 'doubleJump', 'downStrike', 'wallJump'],
      'bossesDefeated': <String>[],
    });

    expect(migrated.roomId, 'energy_e01_reactivation');
    expect(migrated.abilities, isEmpty);
  });
}
