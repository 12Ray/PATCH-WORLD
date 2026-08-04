import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/survival/wave_director.dart';

void main() {
  test('phase hound spawn inset clears the arena collision walls', () {
    final left = SurvivalArenaController.clampSpawnPoint(
      point: const SurvivalSpawnPoint(-48, 120),
      width: 960,
      height: 540,
      inset: SurvivalArenaController.phaseHoundSpawnInset,
    );
    final bottom = SurvivalArenaController.clampSpawnPoint(
      point: const SurvivalSpawnPoint(700, 588),
      width: 960,
      height: 540,
      inset: SurvivalArenaController.phaseHoundSpawnInset,
    );

    expect(left.x, 60);
    expect(left.y, 120);
    expect(bottom.x, 700);
    expect(bottom.y, 480);
    expect(left.x - 14, greaterThan(24));
    expect(540 - bottom.y - 14, greaterThan(24));
  });
}
