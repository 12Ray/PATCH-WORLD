import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/core_signature_gate_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boot_sector_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  test('three core signatures open the visible Optimizer gate state', () {
    final gate = CoreSignatureGateComponent(
      position: Vector2.zero(),
      acquiredSignatures: 3,
      requiredSignatures: 3,
    );
    expect(gate.acquiredSignatures, 3);
    expect(gate.isUnlocked, isTrue);
  });

  testWidgets('Optimizer gate remains visible and reports 0/3 before unlock', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    game.resumeEngine();
    await tester.pump(const Duration(milliseconds: 16));

    final room = game.world.activeRoom! as BootSectorController;
    final gate = room.optimizerGate!;
    expect(gate.acquiredSignatures, 0);
    expect(gate.requiredSignatures, 3);
    expect(gate.isUnlocked, isFalse);
    expect(
      room.children.whereType<CampaignDoorComponent>().map(
        (door) => door.labelLocalizationKey,
      ),
      isNot(contains('interaction.enterOptimizerCore')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
