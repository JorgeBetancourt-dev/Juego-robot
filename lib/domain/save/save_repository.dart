import '../progression/game_progress.dart';

abstract interface class SaveRepository {
  Future<GameProgress?> load();
  Future<void> save(GameProgress progress);
  Future<void> deleteProgress();
}
