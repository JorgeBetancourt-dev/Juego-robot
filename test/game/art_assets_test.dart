import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/game/art/environment_assets.dart';
import 'package:game_final/game/art/sprite_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('environment and character art assets decode successfully', () async {
    final environment = await EnvironmentAssets.load();
    final sprites = await GameSpriteAssets.load();

    expect(environment.images.length, greaterThanOrEqualTo(50));
    expect(environment['tile_normal'].width, 32);
    expect(environment['background_far'].width, 640);
    expect(sprites.m0['idle']!.frames.length, 5);
    expect(sprites.patrol['walk']!.frames.length, 6);
    expect(sprites.watcher['shoot']!.frames.length, 4);
    expect(sprites.drone['patrol']!.frames.length, 5);
    expect(sprites.volt['ground_slam']!.frames.length, 5);
    expect(sprites.volt['missile_projectile']!.frames.length, 3);
  });
}
