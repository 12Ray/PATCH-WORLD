import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/hud_overlay.dart';
import 'package:patch_world/app/overlays/survival_result_overlay.dart';
import 'package:patch_world/app/overlays/title_overlay.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
import 'package:patch_world/services/game_settings.dart';

void main() {
  testWidgets('Phase 13 critical UI fits locale and desktop aspect matrix', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const viewports = <Size>[
      Size(1280, 720), // 16:9
      Size(1280, 800), // 16:10
      Size(2560, 1080), // 21:9 ultrawide
    ];
    final game = PatchWorldGame();
    game.survivalResult.value = const SurvivalResultSnapshot(
      elapsedSeconds: 1200,
      kills: 180,
      eliteKills: 12,
      miniBossKills: 4,
      score: 108000,
      maxCombo: 48,
      hotCachesSpawned: 8,
      hotCachesCollected: 6,
      perfectDodges: 18,
      houndBreaks: 8,
      phaseExecutions: 5,
      patchTiers: <String, int>{
        'patch.motion_tax': 3,
        'patch.frame_burst': 3,
        'patch.phase_leak': 2,
      },
      riskMultiplier: 1.8,
      firstPatchId: 'patch.motion_tax',
      isBestScore: true,
      isBestTime: true,
      meaningfulEventCount: 48,
      longestQuietSeconds: 8,
      eventsPerMinute: 8.4,
      visitedRegionCount: 4,
      regionEventsStarted: 4,
      regionEventsCompleted: 4,
      survivalBossesDefeated: 4,
      finalBossDefeated: true,
    );

    for (final viewport in viewports) {
      tester.view.physicalSize = viewport;
      for (final locale in const <String>['ko', 'en', 'ja']) {
        await game.localization.load(locale);
        game.settings.value = GameSettings(
          languageCode: locale,
          languageSetupComplete: true,
        );
        game.uiSnapshot.value = UiSnapshot(
          integrity: 3,
          maxIntegrity: 7,
          roomLabel: game.localization.text('survival.region.reactorYard'),
          anomalyLabel: game.localization.text('survivalBoss.nexusCore'),
          objectiveLabel: game.localization.text(
            'survivalObjective.boss',
            parameters: const <String, Object>{
              'boss': 'NEXUS CORE',
              'phase': 3,
              'current': 24,
              'max': 72,
            },
          ),
          selectedPatchIds: const <String>[
            'patch.motion_tax',
            'patch.frame_burst',
            'patch.phase_leak',
          ],
          bossHealth: 24,
          bossMaxHealth: 72,
          bossPhase: 'P3',
        );

        for (final overlay in <Widget>[
          TitleOverlay(game: game),
          HudOverlay(game: game),
          SurvivalResultOverlay(game: game),
        ]) {
          await tester.pumpWidget(
            MaterialApp(theme: ThemeData.dark(), home: overlay),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason:
                '$locale ${viewport.width}x${viewport.height} '
                '${overlay.runtimeType}',
          );
        }
      }
    }
  });
}
