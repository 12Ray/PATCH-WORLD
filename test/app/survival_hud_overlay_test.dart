import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/hud_overlay.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('survival HUD shows readable vent and overclock states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    await game.localization.load('en');
    game.uiSnapshot.value = const UiSnapshot(
      integrity: 5,
      maxIntegrity: 5,
      roomLabel: 'PATCH//SURVIVE ARENA',
      anomalyLabel: 'THREAT BUDGET ESCALATING',
      objectiveLabel: 'SURVIVE 120s · KILLS 42 · SCORE 2000',
      selectedPatchIds: <String>['patch.motion_tax', 'patch.frame_burst'],
      survivalLevel: 6,
      survivalExperience: 3,
      survivalExperienceToNext: 10,
      survivalCombo: 10,
      survivalOverclock: true,
      motionVentReady: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: HudOverlay(game: game),
      ),
    );
    expect(find.text('VENT READY'), findsOneWidget);
    expect(find.text('OVERCLOCK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
