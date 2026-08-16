import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/survival_result_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_balance_report.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';

void main() {
  testWidgets('survival result presents run stats and retry choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    await game.localization.load('en');
    game.survivalResult.value = const SurvivalResultSnapshot(
      elapsedSeconds: 91,
      kills: 42,
      eliteKills: 1,
      miniBossKills: 0,
      score: 4242,
      maxCombo: 12,
      hotCachesSpawned: 3,
      hotCachesCollected: 2,
      perfectDodges: 7,
      houndBreaks: 4,
      phaseExecutions: 3,
      patchTiers: <String, int>{'patch.motion_tax': 2, 'patch.phase_leak': 2},
      riskMultiplier: 1.24,
      firstPatchId: 'patch.motion_tax',
      isBestScore: true,
      isBestTime: true,
      meaningfulEventCount: 18,
      longestQuietSeconds: 12.5,
      eventsPerMinute: 11.9,
      deathCauseId: 'enemy.arc_warden.radial',
      damageTaken: 5,
      damageByCause: <String, int>{
        'enemy.arc_warden.radial': 3,
        'hazard.survival.reactorSpill': 2,
      },
      completedWeaponBuilds: 1,
      visitedRegionCount: 3,
      regionEventsStarted: 3,
      regionEventsCompleted: 2,
      regionEventsFailed: 1,
      survivalBossesDefeated: 1,
      itemIds: <String>['railCapacitor', 'ricochetLens'],
      itemSynergyTiers: <String, int>{'projectile': 1},
    );
    game.survivalSessionHistory.add(game.survivalResult.value!);
    game.survivalPlaytestHistory.add(
      SurvivalPlaytestRecord.fromResult(
        game.survivalResult.value!,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SurvivalResultOverlay(game: game),
      ),
    );

    expect(find.text('RUN OVER // SYSTEM COLLAPSE'), findsOneWidget);
    expect(find.text('1:31'), findsOneWidget);
    expect(find.text('BOOT'), findsOneWidget);
    expect(find.text('DEATH CAUSE'), findsOneWidget);
    expect(find.text('DAMAGE TAKEN'), findsOneWidget);
    expect(find.text('BUILDS COMPLETE'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('ZONES VISITED'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('ZONE EVENTS'), findsOneWidget);
    expect(find.text('2/3'), findsWidgets);
    expect(find.text('BOSSES DEFEATED'), findsOneWidget);
    expect(find.text('PATCH ITEMS'), findsOneWidget);
    expect(find.text('Rail Capacitor'), findsOneWidget);
    expect(find.text('Ricochet Lens'), findsOneWidget);
    expect(find.text('ITEM SYNERGIES'), findsOneWidget);
    expect(find.text('PROJECTILE  T1'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('NEXUS CORE'), findsOneWidget);
    expect(find.text('NOT REACHED'), findsOneWidget);
    expect(find.text('4242'), findsOneWidget);
    expect(find.text('MOTION TAX  T2'), findsOneWidget);
    expect(find.text('PHASE LEAK  T2'), findsOneWidget);
    expect(find.text('ACTIVE FUSIONS'), findsOneWidget);
    expect(find.text('GHOST VENT'), findsOneWidget);
    expect(find.text('12.5s'), findsOneWidget);
    expect(find.text('11.9'), findsOneWidget);
    expect(find.text('HOT CACHES'), findsOneWidget);
    expect(find.text('2/3'), findsNWidgets(2));
    expect(find.text('PERFECT DODGES'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('BREAK CONFIRMS'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('PHASE EXECUTIONS'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('PACING CLEAR // NO GAP OVER 20s'), findsOneWidget);
    expect(find.text('PLAYTEST SESSION  1/5'), findsOneWidget);
    expect(find.text('TOP PICK  MOTION TAX  100%'), findsOneWidget);
    expect(find.text('TOP WEAPON  SWORD  100%'), findsOneWidget);
    expect(find.text('PLAYTEST BALANCE AUDIT'), findsOneWidget);
    expect(find.text('COLLECTING SAMPLES'), findsOneWidget);
    expect(find.textContaining('SWORD  1/5'), findsOneWidget);
    expect(find.textContaining('CLEAR RATE SPREAD'), findsOneWidget);
    expect(
      find.text('TOP DAMAGE SOURCE  Arc Warden attack  3'),
      findsOneWidget,
    );
    expect(find.text('INSTANT RETRY'), findsOneWidget);
    expect(find.text('KEEP FIRST PATCH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
