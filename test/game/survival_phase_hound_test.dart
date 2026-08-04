import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/components/effects/survival_score_popup_component.dart';
import 'package:patch_world/game/components/effects/perfect_dodge_burst_component.dart';
import 'package:patch_world/game/components/effects/hound_break_burst_component.dart';
import 'package:patch_world/game/components/enemies/phase_hound_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('phase hound defeat pays data, score, and one kill', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget<PatchWorldGame>(
          game: game,
          overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
            OverlayIds.title: (_, _) => const SizedBox.shrink(),
            OverlayIds.hud: (_, _) => const SizedBox.shrink(),
            OverlayIds.touchControls: (_, _) => const SizedBox.shrink(),
            OverlayIds.survivalUpgrade: (_, _) => const SizedBox.shrink(),
            OverlayIds.survivalResult: (_, _) => const SizedBox.shrink(),
          },
        ),
      ),
    );
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    game.startSurvivalRun();
    await _waitForSurvival(tester, game);
    game.survivalRun.experienceToNext = 999;
    final room = game.world.activeRoom! as SurvivalArenaController;
    late final PhaseHoundComponent hound;
    hound = PhaseHoundComponent(
      entityId: 'phase-hound-integration',
      position: game.world.player.position.clone(),
      targetPosition: () => game.world.player.position,
      onDefeated: () => game.recordSurvivalKillAt(hound.position),
    );
    await room.add(hound);
    await tester.pump(const Duration(milliseconds: 16));
    final dataBefore = game.world.player.dataShardCharge;

    game.survivalRun.seedComboForQa(5);
    final scoreBeforeDodge = game.survivalRun.score;
    final eventsBeforeDodge = game.survivalRun.telemetry
        .snapshot(game.survivalRun.elapsedSeconds)
        .meaningfulEventCount;
    final dodgeScore = game.recordSurvivalPerfectDodge(
      game.world.player.position.clone(),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(dodgeScore, greaterThan(0));
    expect(game.survivalRun.score - scoreBeforeDodge, dodgeScore);
    expect(game.survivalRun.perfectDodges, 1);
    expect(game.survivalRun.kills, 0);
    expect(
      game.world.children.whereType<PerfectDodgeBurstComponent>(),
      hasLength(1),
    );
    expect(
      game.survivalRun.telemetry
              .snapshot(game.survivalRun.elapsedSeconds)
              .meaningfulEventCount -
          eventsBeforeDodge,
      1,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.world.player.dataShardCharge - dataBefore, 1);

    hound.receiveDamage(3);
    hound.receiveDamage(3);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.survivalRun.kills, 1);
    final popup = game.world.children
        .whereType<SurvivalScorePopupComponent>()
        .single;
    expect(popup.score, greaterThan(0));
    expect(popup.kind, SurvivalScorePopupKind.normal);
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.world.player.dataShardCharge - dataBefore, 4);

    late final PhaseHoundComponent breakHound;
    breakHound = PhaseHoundComponent(
      entityId: 'phase-hound-break-integration',
      position: game.world.player.position.clone(),
      targetPosition: () => game.world.player.position + Vector2(220, 0),
      onDefeated: () => game.recordSurvivalKillAt(breakHound.position),
      onBreakDefeated: () => game.recordSurvivalHoundBreak(breakHound.position),
    );
    breakHound.update(1.01);
    breakHound.update(0.66);
    breakHound.update(0.33);
    await room.add(breakHound);
    await tester.pump(const Duration(milliseconds: 16));
    breakHound.position.setFrom(game.world.player.position);
    final killsBeforeBreak = game.survivalRun.kills;
    final experienceBeforeBreak = game.survivalRun.experience;
    final comboBeforeBreak = game.survivalRun.combo;
    final scoreBeforeBreak = game.survivalRun.score;
    final eventsBeforeBreak = game.survivalRun.telemetry
        .snapshot(game.survivalRun.elapsedSeconds)
        .meaningfulEventCount;
    breakHound.receiveDamage(2);
    breakHound.receiveDamage(2);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.survivalRun.houndBreaks, 1);
    expect(game.survivalRun.kills, killsBeforeBreak + 1);
    expect(game.survivalRun.experience, experienceBeforeBreak + 1);
    expect(game.survivalRun.combo, comboBeforeBreak + 1);
    expect(game.survivalRun.score - scoreBeforeBreak, greaterThan(160));
    expect(
      game.survivalRun.telemetry
              .snapshot(game.survivalRun.elapsedSeconds)
              .meaningfulEventCount -
          eventsBeforeBreak,
      2,
    );
    expect(
      game.world.children.whereType<HoundBreakBurstComponent>(),
      hasLength(1),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.world.player.dataShardCharge - dataBefore, 2);
    expect(game.survivalRun.dataSurgeActive, isTrue);

    game.world.player.integrity = 999;
    game.survivalRun.elapsedSeconds = 119;
    for (var frame = 0; frame < 140; frame += 1) {
      await tester.pump(const Duration(milliseconds: 67));
    }
    expect(
      room.children.whereType<PhaseHoundComponent>().length,
      lessThanOrEqualTo(1),
    );
  });
}

Future<void> _waitForSurvival(WidgetTester tester, PatchWorldGame game) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (game.currentRoom == RoomId.survivalArena &&
        game.world.isReady &&
        !game.paused) {
      return;
    }
  }
  throw StateError('Timed out waiting for survival arena');
}
