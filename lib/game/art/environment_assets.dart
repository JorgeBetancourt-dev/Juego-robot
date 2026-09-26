import 'dart:ui';

import 'package:flutter/services.dart';

class EnvironmentAssets {
  const EnvironmentAssets(this.images);

  final Map<String, Image> images;

  Image operator [](String name) => images[name]!;

  static const _names = <String>[
    'background_far',
    'background_mid',
    'background_near',
    'tile_normal',
    'tile_worn',
    'tile_cables',
    'tile_light',
    'tile_wet',
    'platform_full',
    'platform_support',
    'pipe_tee',
    'control_console',
    'arrow_up',
    'infra_bridge',
    'platform_glow',
    'door_closed',
    'door_opening',
    'door_open',
    'door_blocked',
    'door_unlocking',
    'switch_inactive',
    'switch_active',
    'checkpoint_inactive',
    'checkpoint_activating',
    'checkpoint_active',
    'moving_platform_center',
    'spikes_active',
    'electric_floor_inactive',
    'electric_floor_active',
    'collectible_rotate',
    'module_rotate',
    'generator_main',
    'generator_secondary',
    'energy_core',
    'energy_container',
    'electric_panel',
    'electric_panel_sparks',
    'active_cables',
    'damaged_cables',
    'industrial_lamp',
    'tube_light',
    'ambient_light',
    'wear_scratches',
    'wear_rust',
    'wear_crack',
    'wear_oil',
    'wear_electric_leak',
    'wear_exposed_cables',
    'sign_energy',
    'sign_sector',
    'sign_direction',
    'sign_warning',
    'sign_maintenance',
    'sign_exit',
    'arrow_right',
    'arrow_left',
    'symbol_electric',
  ];

  static Future<EnvironmentAssets> load() async {
    final images = <String, Image>{};
    for (final name in _names) {
      images[name] = await _loadImage('assets/environment/$name.png');
    }
    return EnvironmentAssets(images);
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
