import 'package:flutter_test/flutter_test.dart';
import 'package:game_final/domain/progression/game_progress.dart';
import 'package:game_final/domain/progression/gate_requirement.dart';
import 'package:game_final/domain/world/room_catalog.dart';

void main() {
  test('requirements read only their corresponding progress set', () {
    const requirement = GateRequirement(GateRequirementType.ability, 'dash');

    expect(requirement.isMet(const GameProgress()), isFalse);
    expect(requirement.isMet(const GameProgress(abilities: {'dash'})), isTrue);
    expect(
      requirement.isMet(const GameProgress(permissions: {'dash'})),
      isFalse,
    );
  });

  test('catalog exposes the complete E01 to E12 sector', () {
    expect(RoomCatalog.rooms, hasLength(12));
    expect(
      RoomCatalog.rooms['energy_e01_reactivation']!.displayName,
      startsWith('E01'),
    );
    expect(
      RoomCatalog.rooms['energy_e12_volt']!.displayName,
      startsWith('E12'),
    );
  });

  test('upper route requires double jump and the lower route remains open', () {
    final distributor = RoomCatalog.rooms['energy_e02_distributor']!;
    final upperExit = distributor.exits.singleWhere(
      (exit) => exit.targetRoomId == 'energy_e03_lift',
    );
    final lowerExit = distributor.exits.singleWhere(
      (exit) => exit.targetRoomId == 'energy_e06_cooling_shaft',
    );

    expect(upperExit.requirement!.isMet(const GameProgress()), isFalse);
    expect(
      upperExit.requirement!.isMet(
        const GameProgress(abilities: {'doubleJump'}),
      ),
      isTrue,
    );
    expect(lowerExit.requirement, isNull);
  });

  test('no room grants an advanced ability before or after VOLT', () {
    final pickups = RoomCatalog.rooms.values
        .expand((room) => room.abilityPickups)
        .toSet();

    expect(pickups, isEmpty);
    expect(RoomCatalog.rooms['energy_e12_volt']!.hasVolt, isTrue);
  });
}
