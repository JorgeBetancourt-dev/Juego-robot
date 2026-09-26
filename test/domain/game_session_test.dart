import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/domain/progression/game_progress.dart';
import 'package:game_final/domain/session/game_session.dart';

void main() {
  test('temporary Volt challenge never becomes a persistent save', () async {
    final session = GameSession.temporary(
      progress: const GameProgress(
        checkpointId: 'energy_cp_volt',
        roomId: 'energy_e12_volt',
      ),
    );

    expect(session.isTemporary, isTrue);
    expect(session.hasSave, isFalse);
    expect(session.progress.roomId, 'energy_e12_volt');
    expect(session.progress.abilities, isEmpty);

    await session.recordBossDefeated('volt');

    expect(session.progress.bossesDefeated, contains('volt'));
    expect(session.hasSave, isFalse);
  });
}
