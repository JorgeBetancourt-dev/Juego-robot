import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../domain/movement/aabb.dart';

class TiledCell {
  const TiledCell({
    required this.gid,
    required this.x,
    required this.y,
    required this.flipHorizontal,
    required this.flipVertical,
    required this.flipDiagonal,
  });

  final int gid;
  final int x;
  final int y;
  final bool flipHorizontal;
  final bool flipVertical;
  final bool flipDiagonal;
}

enum TiledEnemyType { drone, patrol, watcher, volt }

class TiledEnemyMarker {
  const TiledEnemyMarker({
    required this.type,
    required this.x,
    required this.y,
  });

  final TiledEnemyType type;
  final double x;
  final double y;
}

class TiledCheckpointMarker {
  const TiledCheckpointMarker({
    required this.id,
    required this.x,
    required this.y,
  });

  final String id;
  final double x;
  final double y;

  Aabb get trigger => Aabb(x - 12, y - 50, 75, 82);
  Vec2d respawn({double playerWidth = 28, double playerHeight = 42}) =>
      Vec2d(x + (51 - playerWidth) / 2, y + 32 - playerHeight);
}

class TiledMapData {
  TiledMapData._({
    required this.mapWidth,
    required this.mapHeight,
    required this.tileWidth,
    required this.tileHeight,
    required this.originCellX,
    required this.originCellY,
    required this.maxCellX,
    required this.maxCellY,
    required this.layers,
    required this.cellsByLayer,
    required this.solids,
    required this.oneWayPlatforms,
    required this.hazards,
    required this.enemyMarkers,
    required this.checkpointMarkers,
    required this.profile,
  });

  static const assetPath = 'assets/maps/mapa_del_juego.tmx';
  static const multiplayerAssetPath = 'assets/maps/mapa_multijugador.tmx';

  final int mapWidth;
  final int mapHeight;
  final int tileWidth;
  final int tileHeight;
  final int originCellX;
  final int originCellY;
  final int maxCellX;
  final int maxCellY;
  final List<List<TiledCell>> layers;
  final List<Map<int, TiledCell>> cellsByLayer;
  final List<Aabb> solids;
  final List<Aabb> oneWayPlatforms;
  final List<Aabb> hazards;
  final List<TiledEnemyMarker> enemyMarkers;
  final List<TiledCheckpointMarker> checkpointMarkers;
  final TiledMapProfile profile;

  double get worldWidth =>
      ((maxCellX - originCellX + 1) * tileWidth).toDouble();
  double get worldHeight =>
      ((maxCellY - originCellY + 1) * tileHeight).toDouble();

  static Future<TiledMapData> load({
    String path = assetPath,
    TiledMapProfile profile = TiledMapProfile.campaign,
  }) async {
    final xml = await rootBundle.loadString(path);
    return parse(xml, profile: profile);
  }

  static TiledMapData parse(
    String xml, {
    TiledMapProfile profile = TiledMapProfile.campaign,
  }) {
    final mapTag = RegExp(r'<map\s+([^>]+)>').firstMatch(xml);
    if (mapTag == null) throw const FormatException('TMX sin etiqueta map.');
    final attributes = _attributes(mapTag.group(1)!);
    final width = int.parse(attributes['width']!);
    final height = int.parse(attributes['height']!);
    final tileWidth = int.parse(attributes['tilewidth']!);
    final tileHeight = int.parse(attributes['tileheight']!);
    final layerPattern = RegExp(
      r'<layer\s+([^>]+)>\s*<data\s+[^>]*encoding="base64"[^>]*>([\s\S]*?)</data>\s*</layer>',
    );
    final layers = <List<TiledCell>>[];
    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;

    for (final layerMatch in layerPattern.allMatches(xml)) {
      final layerAttributes = _attributes(layerMatch.group(1)!);
      final layerWidth = int.parse(layerAttributes['width'] ?? '$width');
      final layerHeight = int.parse(layerAttributes['height'] ?? '$height');
      final encoded = layerMatch.group(2)!.replaceAll(RegExp(r'\s'), '');
      final bytes = base64Decode(encoded);
      final expectedBytes = layerWidth * layerHeight * 4;
      if (bytes.lengthInBytes != expectedBytes) {
        throw FormatException(
          'Capa TMX inválida: ${bytes.lengthInBytes} bytes, se esperaban $expectedBytes.',
        );
      }
      final data = ByteData.sublistView(bytes);
      final cells = <TiledCell>[];
      for (var index = 0; index < layerWidth * layerHeight; index++) {
        final raw = data.getUint32(index * 4, Endian.little);
        final gid = raw & 0x1fffffff;
        if (gid == 0) continue;
        final x = index % layerWidth;
        final y = index ~/ layerWidth;
        minX = x < minX ? x : minX;
        minY = y < minY ? y : minY;
        maxX = x > maxX ? x : maxX;
        maxY = y > maxY ? y : maxY;
        cells.add(
          TiledCell(
            gid: gid,
            x: x,
            y: y,
            flipHorizontal: raw & 0x80000000 != 0,
            flipVertical: raw & 0x40000000 != 0,
            flipDiagonal: raw & 0x20000000 != 0,
          ),
        );
      }
      layers.add(cells);
    }
    if (layers.isEmpty || maxX < 0) {
      throw const FormatException('El TMX no contiene tiles pintados.');
    }

    int key(int x, int y) => y * width + x;
    final cellsByLayer = [
      for (final layer in layers)
        {for (final cell in layer) key(cell.x, cell.y): cell},
    ];
    final fullSolidCells = <int>{};
    final solids = <Aabb>[];
    final oneWay = <Aabb>[];
    final hazards = <Aabb>[];
    final enemyMarkers = <TiledEnemyMarker>[];
    final checkpointMarkers = <TiledCheckpointMarker>[];

    double worldX(int cellX) => (cellX - minX) * tileWidth.toDouble();
    double worldY(int cellY) => (cellY - minY) * tileHeight.toDouble();

    for (final layer in layers) {
      for (final cell in layer) {
        final gid = cell.gid;
        if (profile == TiledMapProfile.multiplayer) {
          if (gid == 1) {
            fullSolidCells.add(key(cell.x, cell.y));
          } else if (gid == 2) {
            final top = worldY(cell.y) + tileHeight - 116;
            oneWay.add(Aabb(worldX(cell.x), top, 112, 8));
            solids.add(Aabb(worldX(cell.x) + 46, top + 18, 20, 98));
          } else if (gid == 3) {
            oneWay.add(Aabb(worldX(cell.x), worldY(cell.y) + 4, 160, 8));
          }
          continue;
        }
        if ((gid >= 1 && gid <= 4) || gid == 10 || (gid >= 13 && gid <= 14)) {
          fullSolidCells.add(key(cell.x, cell.y));
        } else if (gid >= 5 && gid <= 7) {
          hazards.add(
            Aabb(
              worldX(cell.x) + 3,
              worldY(cell.y) + 8,
              tileWidth - 6,
              tileHeight - 8,
            ),
          );
        } else if (gid == 8) {
          oneWay.add(Aabb(worldX(cell.x), worldY(cell.y) + 4, 160, 8));
        } else if (gid == 9) {
          final top = worldY(cell.y) + tileHeight - 116;
          oneWay.add(Aabb(worldX(cell.x), top, 112, 8));
          solids.add(Aabb(worldX(cell.x) + 46, top + 18, 20, 98));
        } else if (gid == 11) {
          solids.add(Aabb(worldX(cell.x), worldY(cell.y) - 26, 114, 58));
        } else if (gid == 12) {
          solids.add(Aabb(worldX(cell.x), worldY(cell.y) + 8, 101, 24));
        } else if (gid == 15) {
          solids.add(Aabb(worldX(cell.x), worldY(cell.y) - 57, 108, 89));
        } else if (gid == 16) {
          solids.add(Aabb(worldX(cell.x), worldY(cell.y) - 50, 59, 82));
        } else if (gid == 17) {
          solids.add(Aabb(worldX(cell.x), worldY(cell.y) - 19, 44, 51));
        } else if (gid == 18) {
          oneWay.add(Aabb(worldX(cell.x), worldY(cell.y) + 14, 182, 8));
        } else if (gid >= 20 && gid <= 23) {
          enemyMarkers.add(
            TiledEnemyMarker(
              type: switch (gid) {
                20 => TiledEnemyType.drone,
                21 => TiledEnemyType.patrol,
                22 => TiledEnemyType.watcher,
                _ => TiledEnemyType.volt,
              },
              x: worldX(cell.x),
              y: worldY(cell.y),
            ),
          );
        } else if (gid == 25) {
          checkpointMarkers.add(
            TiledCheckpointMarker(
              id: 'map_checkpoint_${cell.x}_${cell.y}',
              x: worldX(cell.x),
              y: worldY(cell.y),
            ),
          );
        }
      }
    }

    // Horizontal runs keep collision checks small while preserving the exact
    // 32 px silhouette drawn in Tiled.
    for (var y = minY; y <= maxY; y++) {
      var x = minX;
      while (x <= maxX) {
        if (!fullSolidCells.contains(key(x, y))) {
          x++;
          continue;
        }
        final start = x;
        while (x <= maxX && fullSolidCells.contains(key(x, y))) {
          x++;
        }
        solids.add(
          Aabb(
            worldX(start),
            worldY(y),
            (x - start) * tileWidth.toDouble(),
            tileHeight.toDouble(),
          ),
        );
      }
    }

    return TiledMapData._(
      mapWidth: width,
      mapHeight: height,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      originCellX: minX,
      originCellY: minY,
      maxCellX: maxX,
      maxCellY: maxY,
      layers: layers,
      cellsByLayer: cellsByLayer,
      solids: solids,
      oneWayPlatforms: oneWay,
      hazards: hazards,
      enemyMarkers: enemyMarkers,
      checkpointMarkers: checkpointMarkers,
      profile: profile,
    );
  }

  static Map<String, String> _attributes(String source) => {
    for (final match in RegExp(r'(\w+)="([^"]*)"').allMatches(source))
      match.group(1)!: match.group(2)!,
  };
}

enum TiledMapProfile { campaign, multiplayer }
