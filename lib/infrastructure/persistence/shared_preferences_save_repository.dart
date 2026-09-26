import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/progression/game_progress.dart';
import '../../domain/save/save_repository.dart';

class SharedPreferencesSaveRepository implements SaveRepository {
  static const _progressKey = 'system_fallen.progress.v1';
  static const _corruptBackupKey = 'system_fallen.progress.corrupt';

  @override
  Future<GameProgress?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_progressKey);
    if (source == null) return null;
    try {
      final value = jsonDecode(source);
      if (value is! Map<String, Object?>) {
        throw const FormatException('El guardado no contiene un objeto.');
      }
      return GameProgress.fromJson(value);
    } on Object {
      await preferences.setString(_corruptBackupKey, source);
      await preferences.remove(_progressKey);
      return null;
    }
  }

  @override
  Future<void> save(GameProgress progress) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_progressKey, jsonEncode(progress.toJson()));
  }

  @override
  Future<void> deleteProgress() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_progressKey);
  }
}
