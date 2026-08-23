import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/enemy_damage_volume_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('mounted damage volume lifetime follows the enemy clock', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(
      MaterialApp(home: GameWidget<PatchWorldGame>(game: game)),
    );
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    final volume = EnemyDamageVolumeComponent(
      position: Vector2(10000, 10000),
      size: Vector2.all(20),
      sourceId: 'test.enemy-clock',
      activeSeconds: 0.2,
    );
    await tester.runAsync(() async {
      await game.world.add(volume);
    });
    game.update(0);
    await tester.runAsync(() => volume.mounted);

    game.clock.beginFrame(
      realDt: 0.06,
      simulationAdvances: false,
      enemySpeedMultiplier: 1,
    );
    volume.update(1);
    expect(volume.isRemoving, isFalse, reason: 'freeze must preserve lifetime');

    game.clock.beginFrame(
      realDt: 0.06,
      simulationAdvances: true,
      enemySpeedMultiplier: 0.5,
    );
    volume.update(1);
    expect(volume.isRemoving, isFalse, reason: 'slow uses scaled enemy time');

    game.clock.beginFrame(
      realDt: 0.06,
      simulationAdvances: true,
      enemySpeedMultiplier: 2,
    );
    volume.update(0.001);
    expect(volume.isRemoving, isFalse);
    volume.update(0.001);
    expect(volume.isRemoving, isTrue, reason: 'boost accelerates lifetime');
  });
}
