import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'xyz.luan/audioplayers.global/events',
          (message) async =>
              const StandardMethodCodec().encodeSuccessEnvelope(null),
        );
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('xyz.luan/audioplayers.global/events', null);
  });

  testWidgets('campaign start applies and locks the selected loadout', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget(
          game: game,
          overlayBuilderMap:
              <String, Widget Function(BuildContext, PatchWorldGame)>{
                OverlayIds.hud: (_, _) => const SizedBox.shrink(),
                OverlayIds.touchControls: (_, _) => const SizedBox.shrink(),
              },
        ),
      ),
    );
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    unawaited(game.selectStartingWeapon(PlayerWeapon.gauntlet));
    for (var attempt = 0; attempt < 180; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4)),
      );
      if (game.world.isReady &&
          game.world.player.selectedWeapon == PlayerWeapon.gauntlet) {
        break;
      }
      if (attempt == 179) {
        throw StateError('Timed out waiting for gauntlet campaign start.');
      }
    }

    expect(game.selectedRunWeapon, PlayerWeapon.gauntlet);
    expect(game.world.player.selectedWeapon, PlayerWeapon.gauntlet);
    expect(game.world.player.maxIntegrity, 7);
    expect(game.world.player.integrity, 7);

    game.input.handleKeyDown(LogicalKeyboardKey.digit3);
    game.update(.016);
    expect(game.world.player.selectedWeapon, PlayerWeapon.gauntlet);
  });
}
