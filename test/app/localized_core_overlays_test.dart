import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/hud_overlay.dart';
import 'package:patch_world/app/overlays/pause_overlay.dart';
import 'package:patch_world/app/overlays/settings_overlay.dart';
import 'package:patch_world/app/overlays/weapon_build_selection_overlay.dart';
import 'package:patch_world/app/overlays/weapon_selection_overlay.dart';
import 'package:patch_world/game/builds/weapon_build_state.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('core campaign overlays fit Korean English and Japanese', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = PatchWorldGame();
    for (final locale in const <String>['ko', 'en', 'ja']) {
      await game.localization.load(locale);
      game.uiSnapshot.value = UiSnapshot(
        integrity: 7,
        maxIntegrity: 7,
        roomLabel: game.localization.text('room.collisionArchive'),
        anomalyLabel: game.localization.text('boss.kernelChimera.intro'),
        objectiveLabel: game.localization.text('objective.collisionArchive'),
        selectedPatchIds: const <String>[
          'patch.motion_tax',
          'patch.frame_burst',
          'patch.duplicate_fault',
        ],
        bossHealth: 14,
        bossMaxHealth: 20,
        bossPhase: 'phase_three',
      );
      game.pendingWeaponBuildSelection = WeaponBuildSelectionRequest(
        encounterId: 2,
        weapon: PlayerWeapon.gauntlet,
        choices: WeaponBuildCatalog.choicesFor(PlayerWeapon.gauntlet),
      );

      final overlays = <Widget>[
        HudOverlay(game: game),
        PauseOverlay(game: game),
        SettingsOverlay(game: game),
        WeaponSelectionOverlay(game: game),
        WeaponBuildSelectionOverlay(game: game),
      ];
      for (var index = 0; index < overlays.length; index += 1) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
              child: overlays[index],
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'locale=$locale overlayIndex=$index',
        );
      }
    }
  });
}
