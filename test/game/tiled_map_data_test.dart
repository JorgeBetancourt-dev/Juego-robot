import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/domain/config/gameplay_config.dart';
import 'package:game_final/domain/input/input_controller.dart';
import 'package:game_final/domain/movement/aabb.dart';
import 'package:game_final/domain/movement/player_motor.dart';
import 'package:game_final/game/world/tiled_enemy_actor.dart';
import 'package:game_final/game/world/tiled_map_data.dart';

void main() {
  late TiledMapData map;

  setUpAll(() async {
    final source = await File(TiledMapData.assetPath).readAsString();
    map = TiledMapData.parse(source);
  });

  test('carga las seis capas y recorta el lienzo vacío', () {
    expect(map.mapWidth, 500);
    expect(map.mapHeight, 500);
    expect(map.tileWidth, 32);
    expect(map.tileHeight, 32);
    expect(map.layers, hasLength(6));
    expect(map.layers.expand((layer) => layer), hasLength(22650));
    expect(map.originCellX, 190);
    expect(map.originCellY, 100);
    expect(map.maxCellX, 359);
    expect(map.maxCellY, 279);
    expect(map.worldWidth, 5440);
    expect(map.worldHeight, 5760);
  });

  test('interpreta los marcadores de la capa Enemigos', () {
    expect(map.enemyMarkers, hasLength(11));
    expect(
      map.enemyMarkers.where((marker) => marker.type == TiledEnemyType.patrol),
      hasLength(7),
    );
    expect(
      map.enemyMarkers.where((marker) => marker.type == TiledEnemyType.drone),
      hasLength(1),
    );
    expect(
      map.enemyMarkers.where((marker) => marker.type == TiledEnemyType.watcher),
      hasLength(2),
    );
    expect(
      map.enemyMarkers.where((marker) => marker.type == TiledEnemyType.volt),
      hasLength(1),
    );
  });

  test('interpreta los dos puntos de guardado y sus reapariciones', () {
    expect(map.checkpointMarkers, hasLength(2));
    expect(
      map.checkpointMarkers.map((checkpoint) => checkpoint.id),
      containsAll(['map_checkpoint_301_194', 'map_checkpoint_253_211']),
    );
    for (final checkpoint in map.checkpointMarkers) {
      final respawn = checkpoint.respawn();
      final body = Aabb(respawn.x, respawn.y, 28, 42);
      expect(map.solids.any(body.overlaps), isFalse);
      expect(checkpoint.trigger.overlaps(body), isTrue);
    }
  });

  test('los enemigos aparecen fuera de muros y no reciben daño de pinchos', () {
    var index = 0;
    for (final marker in map.enemyMarkers) {
      if (marker.type == TiledEnemyType.volt) {
        final volt = TiledVoltActor(markerX: marker.x, markerY: marker.y);
        expect(map.solids.any(volt.body.overlaps), isFalse);
        continue;
      }
      final enemy = TiledEnemyActor(
        id: 'test_${index++}',
        type: marker.type,
        markerX: marker.x,
        markerY: marker.y,
      );
      expect(map.solids.any(enemy.body.overlaps), isFalse);
      for (var frame = 0; frame < 20; frame++) {
        enemy.update(
          0.05,
          const Aabb(4000, 4406, 28, 42),
          map.solids,
          map.oneWayPlatforms,
        );
      }
      expect(enemy.health, 3);
    }
  });

  test('un VOLT de horda usa su posición y vida sincronizadas', () {
    final volt = TiledEnemyActor(
      id: 'volt_horda',
      type: TiledEnemyType.volt,
      markerX: 0,
      markerY: 0,
      spawnX: 480,
      spawnY: 708,
      maxHealth: 12,
    );

    expect(volt.body.left, 480);
    expect(volt.body.top, 708);
    expect(volt.body.width, 152);
    expect(volt.body.height, 220);
    expect(volt.health, 12);
    volt.setNetworkHealth(0);
    expect(volt.alive, isFalse);
  });

  test('Volt solo activa el encuentro dentro de su sala', () {
    final marker = map.enemyMarkers.singleWhere(
      (candidate) => candidate.type == TiledEnemyType.volt,
    );
    final volt = TiledVoltActor(markerX: marker.x, markerY: marker.y);
    const arena = Aabb(2560, 2592, 1248, 448);

    final outside = volt.update(
      0.05,
      const Aabb(2700, 4300, 28, 42),
      map.solids,
      map.oneWayPlatforms,
      map.worldWidth,
      arena,
    );
    final inside = volt.update(
      0.05,
      const Aabb(3000, 2850, 28, 42),
      map.solids,
      map.oneWayPlatforms,
      map.worldWidth,
      arena,
    );

    expect(outside, isFalse);
    expect(inside, isTrue);
  });

  test('genera colisiones para paredes, plataformas y pinchos', () {
    expect(map.solids.length, greaterThan(300));
    expect(map.oneWayPlatforms, hasLength(49));
    expect(map.hazards, hasLength(92));
  });

  test('el punto inicial está libre y apoyado sobre el suelo', () {
    const body = Aabb(4000, 4406, 28, 42);
    expect(map.solids.any(body.overlaps), isFalse);
    expect(map.hazards.any(body.overlaps), isFalse);
    expect(
      map.solids.any(
        (solid) =>
            (solid.top - body.bottom).abs() < 0.01 &&
            solid.left < body.right &&
            solid.right > body.left,
      ),
      isTrue,
    );
  });

  test('las plataformas largas se atraviesan desde abajo', () {
    const config = GameplayConfig();
    const platform = Aabb(100, 200, 160, 8);
    final motor = PlayerMotor(
      config: config,
      initialPosition: const Vec2d(130, 215),
    );
    motor.applyKnockback(const Vec2d(0, -500));

    motor.update(
      0.04,
      const PlayerInputFrame(
        horizontal: 0,
        downHeld: false,
        jumpHeld: true,
        jumpPressed: false,
        attackPressed: false,
        dashPressed: false,
      ),
      const [],
      oneWayPlatforms: const [platform],
    );

    expect(motor.position.y, lessThan(215));
    expect(motor.velocity.y, lessThan(0));
  });

  test('el mapa multijugador usa su perfil sin alterar la campaña', () async {
    final source = await File(TiledMapData.multiplayerAssetPath).readAsString();
    final multiplayerMap = TiledMapData.parse(
      source,
      profile: TiledMapProfile.multiplayer,
    );

    expect(multiplayerMap.profile, TiledMapProfile.multiplayer);
    expect(multiplayerMap.mapWidth, 40);
    expect(multiplayerMap.mapHeight, 40);
    expect(multiplayerMap.layers, hasLength(2));
    expect(multiplayerMap.layers.expand((layer) => layer), hasLength(868));
    expect(multiplayerMap.worldWidth, 1280);
    expect(multiplayerMap.worldHeight, 960);
    expect(multiplayerMap.oneWayPlatforms, hasLength(4));
    expect(multiplayerMap.hazards, isEmpty);
    expect(multiplayerMap.enemyMarkers, isEmpty);
    expect(multiplayerMap.checkpointMarkers, isEmpty);

    final spawns = [
      for (var index = 0; index < 4; index++)
        multiplayerMap.multiplayerSpawnFor(spawnIndex: index)!,
    ];
    expect(spawns.map((spawn) => spawn.y), everyElement(378));
    expect(spawns.map((spawn) => spawn.x), [476, 700, 552, 776]);
  });
}
