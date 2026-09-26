import '../movement/aabb.dart';
import '../progression/gate_requirement.dart';
import 'room_definition.dart';

/// Primer sector jugable: desde la reactivación de M-0 hasta VOLT.
///
/// La ruta inferior es completable únicamente con movimiento, salto y ataque.
/// La ruta superior queda anunciada desde E02, pero exige doble salto y no forma
/// parte de la progresión necesaria para derrotar al primer jefe.
class RoomCatalog {
  RoomCatalog._();

  static const _floor = Aabb(0, 650, 1280, 70);
  static const _doubleJump = GateRequirement(
    GateRequirementType.ability,
    'doubleJump',
  );

  static final Map<String, RoomDefinition> rooms = {
    for (final room in _definitions) room.id: room,
  };

  static RoomDefinition byId(String id) => rooms[id] ?? _definitions.first;

  static final List<RoomDefinition> _definitions = [
    RoomDefinition(
      id: 'energy_e01_reactivation',
      displayName: 'E01  CÁMARA DE REACTIVACIÓN',
      spawn: const Vec2d(110, 560),
      checkpointId: 'energy_cp_reactivation',
      solids: const [_floor, Aabb(330, 560, 180, 24)],
      oneWayPlatforms: const [Aabb(610, 500, 160, 14)],
      exits: const [
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e02_distributor',
          targetSpawn: Vec2d(45, 560),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e02_distributor',
      displayName: 'E02  DISTRIBUIDOR CENTRAL',
      spawn: const Vec2d(45, 560),
      solids: const [
        Aabb(0, 650, 520, 70),
        Aabb(760, 650, 520, 70),
        Aabb(260, 520, 150, 20),
        Aabb(870, 520, 150, 20),
      ],
      oneWayPlatforms: const [
        Aabb(550, 535, 180, 14),
        Aabb(555, 445, 170, 14),
        Aabb(565, 355, 150, 14),
        Aabb(575, 265, 130, 14),
        Aabb(585, 175, 110, 14),
        Aabb(595, 85, 90, 14),
      ],
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e01_reactivation',
          targetSpawn: Vec2d(1190, 560),
        ),
        RoomExit(
          side: ExitSide.top,
          targetRoomId: 'energy_e03_lift',
          targetSpawn: Vec2d(900, 560),
          requirement: _doubleJump,
        ),
        RoomExit(
          side: ExitSide.bottom,
          targetRoomId: 'energy_e06_cooling_shaft',
          targetSpawn: Vec2d(610, 30),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e09_relay',
          targetSpawn: Vec2d(45, 560),
          requirement: GateRequirement(
            GateRequirementType.worldFlag,
            'relay_shortcut',
          ),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e03_lift',
      displayName: 'E03  ASCENSOR DE MANTENIMIENTO',
      spawn: const Vec2d(900, 560),
      solids: const [
        Aabb(0, 650, 500, 70),
        Aabb(760, 650, 520, 70),
        Aabb(220, 550, 170, 24),
        Aabb(500, 455, 150, 24),
        Aabb(780, 360, 150, 24),
      ],
      oneWayPlatforms: const [Aabb(1000, 500, 130, 14)],
      exits: const [
        RoomExit(
          side: ExitSide.bottom,
          targetRoomId: 'energy_e02_distributor',
          targetSpawn: Vec2d(900, 560),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e04_turbines',
          targetSpawn: Vec2d(45, 560),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e04_turbines',
      displayName: 'E04  GALERÍA DE TURBINAS',
      spawn: const Vec2d(45, 560),
      solids: const [_floor, Aabb(420, 540, 170, 24)],
      oneWayPlatforms: const [Aabb(680, 455, 150, 14), Aabb(920, 370, 150, 14)],
      hasDrone: true,
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e03_lift',
          targetSpawn: Vec2d(1190, 560),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e05_control',
          targetSpawn: Vec2d(45, 560),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e05_control',
      displayName: 'E05  CENTRO DE CONTROL',
      spawn: const Vec2d(45, 560),
      solids: const [
        Aabb(0, 650, 500, 70),
        Aabb(760, 650, 520, 70),
        Aabb(520, 520, 220, 24),
      ],
      oneWayPlatforms: const [Aabb(550, 430, 160, 14)],
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e04_turbines',
          targetSpawn: Vec2d(1190, 560),
        ),
        RoomExit(
          side: ExitSide.bottom,
          targetRoomId: 'energy_e09_relay',
          targetSpawn: Vec2d(830, 40),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e06_cooling_shaft',
      displayName: 'E06  POZO DE REFRIGERACIÓN',
      spawn: const Vec2d(610, 30),
      solids: const [_floor, Aabb(0, 0, 470, 36), Aabb(810, 0, 470, 36)],
      oneWayPlatforms: const [
        Aabb(570, 560, 140, 14),
        Aabb(420, 470, 140, 14),
        Aabb(590, 380, 140, 14),
        Aabb(420, 290, 140, 14),
        Aabb(590, 200, 140, 14),
        Aabb(520, 110, 220, 14),
      ],
      exits: const [
        RoomExit(
          side: ExitSide.top,
          targetRoomId: 'energy_e02_distributor',
          targetSpawn: Vec2d(900, 560),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e07_cooling_ducts',
          targetSpawn: Vec2d(45, 560),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e07_cooling_ducts',
      displayName: 'E07  CONDUCTOS DE REFRIGERACIÓN',
      spawn: const Vec2d(45, 560),
      solids: const [
        Aabb(0, 650, 300, 70),
        Aabb(390, 650, 300, 70),
        Aabb(790, 650, 490, 70),
      ],
      oneWayPlatforms: const [Aabb(305, 535, 80, 14), Aabb(695, 510, 90, 14)],
      hazards: const [Aabb(300, 630, 90, 20), Aabb(690, 630, 100, 20)],
      hasPatrol: true,
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e06_cooling_shaft',
          targetSpawn: Vec2d(1190, 560),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e08_capacitors',
          targetSpawn: Vec2d(45, 560),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e08_capacitors',
      displayName: 'E08  BANCO DE CAPACITORES',
      spawn: const Vec2d(45, 560),
      solids: const [_floor, Aabb(0, 0, 500, 36), Aabb(780, 0, 500, 36)],
      oneWayPlatforms: const [
        Aabb(250, 550, 160, 14),
        Aabb(450, 460, 150, 14),
        Aabb(650, 370, 150, 14),
        Aabb(470, 280, 150, 14),
        Aabb(650, 190, 150, 14),
        Aabb(520, 100, 240, 14),
      ],
      hasMovingPlatform: true,
      hasSwitch: true,
      switchFlag: 'aux_power',
      switchMessage: 'ENERGÍA AUXILIAR RESTABLECIDA',
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e07_cooling_ducts',
          targetSpawn: Vec2d(1190, 560),
        ),
        RoomExit(
          side: ExitSide.top,
          targetRoomId: 'energy_e09_relay',
          targetSpawn: Vec2d(1050, 560),
          requirement: GateRequirement(
            GateRequirementType.worldFlag,
            'aux_power',
          ),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e09_relay',
      displayName: 'E09  RELÉ CENTRAL',
      spawn: const Vec2d(1050, 560),
      solids: const [
        Aabb(0, 650, 720, 70),
        Aabb(940, 650, 340, 70),
        Aabb(0, 0, 720, 36),
        Aabb(940, 0, 340, 36),
      ],
      oneWayPlatforms: const [
        Aabb(310, 520, 140, 14),
        Aabb(720, 430, 170, 14),
        Aabb(750, 340, 140, 14),
        Aabb(720, 250, 140, 14),
        Aabb(750, 160, 140, 14),
        Aabb(740, 70, 160, 14),
      ],
      hasPatrol: true,
      hasWatcher: true,
      hasSwitch: true,
      switchFlag: 'relay_shortcut',
      switchMessage: 'ATAJO AL DISTRIBUIDOR ABIERTO',
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e02_distributor',
          targetSpawn: Vec2d(1190, 560),
          requirement: GateRequirement(
            GateRequirementType.worldFlag,
            'relay_shortcut',
          ),
        ),
        RoomExit(
          side: ExitSide.top,
          targetRoomId: 'energy_e05_control',
          targetSpawn: Vec2d(620, 560),
          requirement: _doubleJump,
        ),
        RoomExit(
          side: ExitSide.bottom,
          targetRoomId: 'energy_e08_capacitors',
          targetSpawn: Vec2d(620, 70),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e10_high_voltage',
          targetSpawn: Vec2d(45, 560),
          requirement: GateRequirement(
            GateRequirementType.worldFlag,
            'aux_power',
          ),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e10_high_voltage',
      displayName: 'E10  CORREDOR DE ALTO VOLTAJE',
      spawn: const Vec2d(45, 560),
      solids: const [
        Aabb(0, 650, 300, 70),
        Aabb(405, 650, 310, 70),
        Aabb(825, 650, 225, 70),
        Aabb(1180, 650, 100, 70),
      ],
      oneWayPlatforms: const [
        Aabb(305, 525, 95, 14),
        Aabb(720, 500, 100, 14),
        Aabb(920, 410, 140, 14),
      ],
      hazards: const [Aabb(300, 630, 105, 20), Aabb(715, 630, 110, 20)],
      hasDrone: true,
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e09_relay',
          targetSpawn: Vec2d(1190, 560),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e11_isolation',
          targetSpawn: Vec2d(45, 560),
        ),
        RoomExit(
          side: ExitSide.bottom,
          targetRoomId: 'energy_e02_distributor',
          targetSpawn: Vec2d(920, 560),
          requirement: GateRequirement(GateRequirementType.ability, 'dash'),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e11_isolation',
      displayName: 'E11  CÁMARA DE AISLAMIENTO',
      spawn: const Vec2d(45, 560),
      checkpointId: 'energy_cp_volt',
      solids: const [_floor, Aabb(360, 540, 160, 24), Aabb(790, 540, 160, 24)],
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e10_high_voltage',
          targetSpawn: Vec2d(1190, 560),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e12_volt',
          targetSpawn: Vec2d(45, 560),
        ),
      ],
    ),
    RoomDefinition(
      id: 'energy_e12_volt',
      displayName: 'E12  NÚCLEO DE VOLT',
      spawn: const Vec2d(45, 560),
      solids: const [_floor, Aabb(260, 535, 160, 24), Aabb(860, 535, 160, 24)],
      hasVolt: true,
      exits: const [
        RoomExit(
          side: ExitSide.left,
          targetRoomId: 'energy_e11_isolation',
          targetSpawn: Vec2d(1190, 560),
        ),
        RoomExit(
          side: ExitSide.right,
          targetRoomId: 'energy_e10_high_voltage',
          targetSpawn: Vec2d(45, 560),
          requirement: GateRequirement(
            GateRequirementType.bossDefeated,
            'volt',
          ),
        ),
      ],
    ),
  ];
}
