import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/hud_overlay.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
import 'package:patch_world/game/systems/frame_burst_controller.dart';

void main() {
  testWidgets('HUD fits boss and localized regional objectives', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    final localizedObjectives =
        <({String languageCode, String anomaly, String objective})>[];
    for (final languageCode in <String>['ko', 'en', 'ja']) {
      await game.localization.load(languageCode);
      for (final objectiveKey in <String>[
        'objective.temporalAscentTask',
        'objective.temporalFractureTask',
        'objective.temporalPendulumTask',
        'objective.collisionCompressionTask',
        'objective.collisionFractureTask',
        'objective.collisionMergeTask',
      ]) {
        localizedObjectives.add((
          languageCode: languageCode,
          anomaly: game.localization.text('rule.collisionMerge'),
          objective: game.localization.text(
            objectiveKey,
            parameters: const <String, Object>{
              'objective': 2,
              'total': 3,
              'defeated': 3,
              'enemies': 4,
              'time': 9,
            },
          ),
        ));
      }
    }
    await game.localization.load('ko');
    game.uiSnapshot.value = const UiSnapshot(
      integrity: 5,
      maxIntegrity: 5,
      roomLabel: 'OPTIMIZATION CORE',
      anomalyLabel: '패턴 분석 중',
      objectiveLabel: '목표: 안정성 75/150',
      selectedPatchIds: <String>[
        'patch.motion_tax',
        'patch.frame_burst',
        'patch.duplicate_fault',
      ],
      normalizedHeat: 0.8,
      frameBurstPhase: FrameBurstPhase.active,
      bossHealth: 6,
      bossMaxHealth: 20,
      bossStability: 75,
      bossPhase: 'perfect',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
          child: HudOverlay(game: game),
        ),
      ),
    );

    expect(find.textContaining('OPTIMIZATION CORE'), findsOneWidget);
    expect(find.textContaining('75/150'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('campaign-boss-bar')),
      findsOneWidget,
    );
    expect(
      find.text(game.localization.text('boss.optimizer.name')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    for (final localized in localizedObjectives) {
      game.uiSnapshot.value = UiSnapshot(
        integrity: 3,
        maxIntegrity: 3,
        roomLabel: 'COLLISION ARCHIVE',
        anomalyLabel: localized.anomaly,
        objectiveLabel: localized.objective,
        selectedPatchIds: const <String>[],
        selectedWeapon: PlayerWeapon.gun,
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: localized.languageCode);
    }

    game.mode = PatchWorldMode.survival;
    game.uiSnapshot.value = const UiSnapshot(
      integrity: 4,
      maxIntegrity: 5,
      roomLabel: 'PATCH//SURVIVE',
      anomalyLabel: 'NEXUS CORE',
      objectiveLabel: 'SURVIVE',
      selectedPatchIds: <String>[],
      bossHealth: 120,
      bossMaxHealth: 200,
      bossPhase: 'crisis',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('campaign-boss-bar')),
      findsNothing,
    );
    expect(find.textContaining('120/200'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
