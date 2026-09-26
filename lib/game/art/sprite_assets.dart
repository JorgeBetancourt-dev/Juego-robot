import 'dart:ui';

import 'package:flutter/services.dart';

class SpriteSequence {
  const SpriteSequence(this.frames, {required this.frameTime});

  final List<Image> frames;
  final double frameTime;

  Image frameAt(double elapsed, {bool loop = true}) {
    if (frames.length == 1) return frames.first;
    final rawIndex = (elapsed / frameTime).floor();
    final index = loop
        ? rawIndex % frames.length
        : rawIndex.clamp(0, frames.length - 1).toInt();
    return frames[index];
  }
}

class GameSpriteAssets {
  const GameSpriteAssets({
    required this.m0,
    required this.patrol,
    required this.watcher,
    required this.watcherProjectile,
    required this.drone,
    required this.droneProjectile,
    required this.volt,
  });

  final Map<String, SpriteSequence> m0;
  final Map<String, SpriteSequence> patrol;
  final Map<String, SpriteSequence> watcher;
  final Map<String, SpriteSequence> watcherProjectile;
  final Map<String, SpriteSequence> drone;
  final Map<String, SpriteSequence> droneProjectile;
  final Map<String, SpriteSequence> volt;

  static Future<GameSpriteAssets> load() async => GameSpriteAssets(
    m0: await _loadCharacter('m0', const {
      'idle': 5,
      'run': 6,
      'rise': 3,
      'fall': 4,
      'land': 3,
      'attack': 4,
      'dash': 3,
      'wall_slide': 2,
      'wall_jump': 3,
      'double_jump': 4,
      'down_strike': 3,
      'hurt': 3,
      'death': 4,
      'respawn': 4,
    }),
    patrol: await _loadCharacter('patrol', const {
      'idle': 4,
      'walk': 6,
      'turn': 4,
      'attack': 5,
      'hurt': 4,
      'death': 5,
    }),
    watcher: await _loadCharacter('watcher', const {
      'idle': 4,
      'detect': 4,
      'aim': 4,
      'shoot': 4,
      'cooldown': 5,
    }),
    watcherProjectile: await _loadCharacter('watcher_projectile', const {
      'fly': 5,
      'impact': 5,
    }),
    drone: await _loadCharacter('drone', const {
      'idle': 6,
      'patrol': 5,
      'turn': 5,
      'shoot': 3,
      'charge': 5,
      'hurt': 5,
      'death': 6,
    }),
    droneProjectile: await _loadCharacter('drone_projectile', const {'fly': 6}),
    volt: await _loadNamedCharacter('volt', const {
      'idle': [
        'idle_breathe_01',
        'idle_breathe_02',
        'idle_breathe_03',
        'idle_breathe_04',
        'idle_breathe_05',
      ],
      'walk': [
        'walk_step_01',
        'walk_step_02',
        'walk_step_03',
        'walk_step_04',
        'walk_step_05',
        'walk_step_06',
      ],
      'core_charge': [
        'core_charge_01',
        'core_charge_02',
        'core_charge_03',
        'core_charge_04',
        'core_charge_05',
      ],
      'ground_slam': [
        'ground_slam_raise',
        'ground_slam_windup',
        'ground_slam_descend',
        'ground_slam_impact_01',
        'ground_slam_impact_02',
      ],
      'missile_launch': ['missile_launcher_ready', 'missile_launcher_fire'],
      'missile_projectile': [
        'missile_projectile_flight_01',
        'missile_projectile_flight_02',
        'missile_projectile_flight_03',
      ],
      'missile_impact': [
        'missile_impact_01',
        'missile_impact_02',
        'missile_impact_03',
      ],
      'vulnerable': [
        'vulnerable_core_open_01',
        'vulnerable_core_open_02',
        'vulnerable_core_open_03',
      ],
      'hurt': ['hurt_recoil_01', 'hurt_recoil_02', 'hurt_recoil_03'],
      'defeat': [
        'defeat_stagger',
        'defeat_collapse_01',
        'defeat_collapse_02',
        'defeat_destroyed',
      ],
    }),
  );

  static Future<Map<String, SpriteSequence>> _loadNamedCharacter(
    String character,
    Map<String, List<String>> animations,
  ) async {
    final result = <String, SpriteSequence>{};
    for (final entry in animations.entries) {
      final frames = <Image>[];
      for (final filename in entry.value) {
        frames.add(
          await _loadImage(
            'assets/sprites/$character/${entry.key}/$filename.png',
          ),
        );
      }
      final frameTime = switch (entry.key) {
        'idle' || 'walk' => 0.16,
        'core_charge' || 'ground_slam' || 'missile_launch' => 0.18,
        'vulnerable' || 'hurt' => 0.18,
        'defeat' => 0.22,
        _ => 0.14,
      };
      result[entry.key] = SpriteSequence(frames, frameTime: frameTime);
    }
    return result;
  }

  static Future<Map<String, SpriteSequence>> _loadCharacter(
    String character,
    Map<String, int> animations,
  ) async {
    final result = <String, SpriteSequence>{};
    for (final entry in animations.entries) {
      final frames = <Image>[];
      for (var index = 0; index < entry.value; index++) {
        final suffix = index.toString().padLeft(2, '0');
        frames.add(
          await _loadImage(
            'assets/sprites/$character/${entry.key}/frame_$suffix.png',
          ),
        );
      }
      final slow =
          entry.key == 'idle' || entry.key == 'walk' || entry.key == 'patrol';
      result[entry.key] = SpriteSequence(frames, frameTime: slow ? 0.14 : 0.10);
    }
    return result;
  }

  static Future<Image> _loadImage(String path) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}
