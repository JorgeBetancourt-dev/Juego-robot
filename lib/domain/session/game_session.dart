import 'package:flutter/foundation.dart';

import '../progression/game_progress.dart';
import '../save/save_repository.dart';

class GameSession extends ChangeNotifier {
  GameSession(this._repository);

  GameSession.temporary({required this.progress}) : _repository = null;

  final SaveRepository? _repository;
  GameProgress progress = const GameProgress();
  bool hasSave = false;

  bool get isTemporary => _repository == null;

  Future<void> load() async {
    final loaded = await _repository?.load();
    if (loaded != null) {
      progress = loaded;
      hasSave = true;
    }
    notifyListeners();
  }

  Future<void> startNewGame() async {
    progress = const GameProgress();
    hasSave = !isTemporary;
    await _repository?.save(progress);
    notifyListeners();
  }

  Future<void> activateCheckpoint(String checkpointId, String roomId) async {
    progress = progress.copyWith(checkpointId: checkpointId, roomId: roomId);
    hasSave = !isTemporary;
    await _repository?.save(progress);
    notifyListeners();
  }

  Future<void> unlockAbility(String abilityId) async {
    await unlockAbilities([abilityId]);
  }

  Future<void> unlockAbilities(Iterable<String> abilityIds) async {
    progress = progress.copyWith(
      abilities: {...progress.abilities, ...abilityIds},
    );
    hasSave = !isTemporary;
    await _repository?.save(progress);
    notifyListeners();
  }

  Future<void> grantPermission(String permissionId) async {
    progress = progress.copyWith(
      permissions: {...progress.permissions, permissionId},
    );
    await _persist();
  }

  Future<void> setWorldFlag(String flagId) async {
    progress = progress.copyWith(worldFlags: {...progress.worldFlags, flagId});
    await _persist();
  }

  Future<void> recordSecret(String secretId) async {
    progress = progress.copyWith(
      secretsFound: {...progress.secretsFound, secretId},
    );
    await _persist();
  }

  Future<void> recordBossDefeated(String bossId) async {
    progress = progress.copyWith(
      bossesDefeated: {...progress.bossesDefeated, bossId},
    );
    await _persist();
  }

  Future<void> _persist() async {
    hasSave = !isTemporary;
    await _repository?.save(progress);
    notifyListeners();
  }
}
