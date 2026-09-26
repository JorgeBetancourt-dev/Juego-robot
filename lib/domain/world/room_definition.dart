import '../movement/aabb.dart';
import '../progression/gate_requirement.dart';

enum ExitSide { left, right, top, bottom }

class RoomExit {
  const RoomExit({
    required this.side,
    required this.targetRoomId,
    required this.targetSpawn,
    this.requirement,
  });

  final ExitSide side;
  final String targetRoomId;
  final Vec2d targetSpawn;
  final GateRequirement? requirement;
}

class RoomDefinition {
  const RoomDefinition({
    required this.id,
    required this.displayName,
    required this.spawn,
    required this.solids,
    required this.exits,
    this.oneWayPlatforms = const [],
    this.hazards = const [],
    this.checkpointId,
    this.abilityPickups = const [],
    this.permissionPickup,
    this.secretId,
    this.hasPatrol = false,
    this.hasWatcher = false,
    this.hasDrone = false,
    this.hasVolt = false,
    this.hasMovingPlatform = false,
    this.hasSwitch = false,
    this.switchFlag = 'machinery_switch',
    this.switchMessage = 'INTERRUPTOR ACTIVADO',
    this.breakableBarrier,
  });

  final String id;
  final String displayName;
  final Vec2d spawn;
  final List<Aabb> solids;
  final List<Aabb> oneWayPlatforms;
  final List<Aabb> hazards;
  final List<RoomExit> exits;
  final String? checkpointId;
  final List<String> abilityPickups;
  final String? permissionPickup;
  final String? secretId;
  final bool hasPatrol;
  final bool hasWatcher;
  final bool hasDrone;
  final bool hasVolt;
  final bool hasMovingPlatform;
  final bool hasSwitch;
  final String switchFlag;
  final String switchMessage;
  final Aabb? breakableBarrier;
}
