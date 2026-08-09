import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

void main() {
  test('collision archive exposes four enemies and one mid-boss concept', () {
    const roomThree = <PlatformerEnemyArchetype>[
      PlatformerEnemyArchetype.vectorRam,
      PlatformerEnemyArchetype.polarityDrone,
      PlatformerEnemyArchetype.phaseMimic,
      PlatformerEnemyArchetype.shardLobber,
      PlatformerEnemyArchetype.kernelChimera,
    ];

    expect(roomThree.map((item) => item.displayName).toSet(), hasLength(5));
    expect(
      roomThree.where((item) => item.isMidBoss),
      <PlatformerEnemyArchetype>[PlatformerEnemyArchetype.kernelChimera],
    );
  });
}
