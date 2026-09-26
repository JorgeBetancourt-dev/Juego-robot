import 'game_progress.dart';

enum GateRequirementType { ability, permission, worldFlag, bossDefeated }

class GateRequirement {
  const GateRequirement(this.type, this.id);

  final GateRequirementType type;
  final String id;

  bool isMet(GameProgress progress) => switch (type) {
    GateRequirementType.ability => progress.abilities.contains(id),
    GateRequirementType.permission => progress.permissions.contains(id),
    GateRequirementType.worldFlag => progress.worldFlags.contains(id),
    GateRequirementType.bossDefeated => progress.bossesDefeated.contains(id),
  };

  String get label => switch (type) {
    GateRequirementType.ability => 'MÓDULO ${_abilityLabel(id)}',
    GateRequirementType.permission => 'PERMISO ${id.toUpperCase()}',
    GateRequirementType.worldFlag => 'SISTEMA ${id.toUpperCase()}',
    GateRequirementType.bossDefeated => 'OBJETIVO ${id.toUpperCase()}',
  };

  static String _abilityLabel(String id) => switch (id) {
    'doubleJump' => 'DOBLE SALTO',
    'downStrike' => 'GOLPE DESCENDENTE',
    'wallJump' => 'SALTO EN PARED',
    _ => id.toUpperCase(),
  };
}
