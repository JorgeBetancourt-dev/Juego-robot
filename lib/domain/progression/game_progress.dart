class GameProgress {
  const GameProgress({
    this.schemaVersion = currentSchemaVersion,
    this.checkpointId = 'energy_cp_reactivation',
    this.roomId = 'energy_e01_reactivation',
    this.abilities = const {},
    this.permissions = const {},
    this.bossesDefeated = const {},
    this.worldFlags = const {},
    this.secretsFound = const {},
  });

  static const currentSchemaVersion = 2;

  final int schemaVersion;
  final String checkpointId;
  final String roomId;
  final Set<String> abilities;
  final Set<String> permissions;
  final Set<String> bossesDefeated;
  final Set<String> worldFlags;
  final Set<String> secretsFound;

  GameProgress copyWith({
    String? checkpointId,
    String? roomId,
    Set<String>? abilities,
    Set<String>? permissions,
    Set<String>? bossesDefeated,
    Set<String>? worldFlags,
    Set<String>? secretsFound,
  }) {
    return GameProgress(
      checkpointId: checkpointId ?? this.checkpointId,
      roomId: roomId ?? this.roomId,
      abilities: abilities ?? this.abilities,
      permissions: permissions ?? this.permissions,
      bossesDefeated: bossesDefeated ?? this.bossesDefeated,
      worldFlags: worldFlags ?? this.worldFlags,
      secretsFound: secretsFound ?? this.secretsFound,
    );
  }

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'checkpointId': checkpointId,
    'roomId': roomId,
    'abilities': abilities.toList()..sort(),
    'permissions': permissions.toList()..sort(),
    'bossesDefeated': bossesDefeated.toList()..sort(),
    'worldFlags': worldFlags.toList()..sort(),
    'secretsFound': secretsFound.toList()..sort(),
  };

  factory GameProgress.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version > currentSchemaVersion) {
      throw const FormatException('Versión de guardado no compatible.');
    }
    Set<String> readSet(String key) =>
        ((json[key] as List<Object?>?) ?? const []).whereType<String>().toSet();
    if (version < 2) {
      final defeated = readSet('bossesDefeated');
      return GameProgress(
        abilities: defeated.contains('volt') ? const {'dash'} : const {},
        bossesDefeated: defeated,
        secretsFound: readSet('secretsFound'),
      );
    }
    return GameProgress(
      checkpointId: json['checkpointId'] as String? ?? 'energy_cp_reactivation',
      roomId: json['roomId'] as String? ?? 'energy_e01_reactivation',
      abilities: readSet('abilities'),
      permissions: readSet('permissions'),
      bossesDefeated: readSet('bossesDefeated'),
      worldFlags: readSet('worldFlags'),
      secretsFound: readSet('secretsFound'),
    );
  }
}
