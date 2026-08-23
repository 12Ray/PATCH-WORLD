import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_pattern_catalog.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets(
    'lethal hits obey attack-completion gates and strict phase order',
    (tester) async {
      final game = PatchWorldGame();
      await tester.pumpWidget(
        MaterialApp(home: GameWidget<PatchWorldGame>(game: game)),
      );
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);

      final phaseChanges = <CampaignChapterBossPhase>[];
      final boss = CampaignChapterBossComponent(
        position: Vector2.all(10000),
        kind: CampaignChapterBossKind.chronoJailer,
        onDefeated: () {},
        onPhaseChanged: phaseChanges.add,
      );
      await tester.runAsync(() async {
        await game.world.add(boss);
      });
      game.update(0);
      await tester.runAsync(() => boss.mounted);
      boss.beginIntro();
      boss.activate();

      expect(boss.phase, CampaignChapterBossPhase.phaseOne);
      boss.receiveDamage(999);
      expect(
        boss.phase,
        CampaignChapterBossPhase.phaseOne,
        reason: 'one lethal event cannot skip an unplayed phase-one attack',
      );
      expect(boss.health, 13);
      expect(boss.hasCompletedAttackInCurrentPhase, isFalse);

      _advanceUntilPhase(game, boss, CampaignChapterBossPhase.phaseTwo);
      expect(boss.health, 13);
      expect(boss.isPhaseTransitioning, isTrue);
      expect(boss.attackVisualPhase, CampaignBossAttackVisualPhase.idle);
      expect(boss.spawnedHazardCount, 0);

      boss.receiveDamage(999);
      expect(
        boss.health,
        13,
        reason: 'the transition quiet window must also be invulnerable',
      );
      _advanceSeconds(
        game,
        boss,
        CampaignBossPhaseGateSpec.transitionQuietSeconds + .1,
      );
      expect(boss.isPhaseTransitioning, isFalse);

      boss.receiveDamage(999);
      expect(boss.phase, CampaignChapterBossPhase.phaseTwo);
      expect(boss.health, 6);
      _advanceUntilPhase(game, boss, CampaignChapterBossPhase.phaseThree);
      expect(boss.health, 6);

      _advanceSeconds(
        game,
        boss,
        CampaignBossPhaseGateSpec.transitionQuietSeconds + .1,
      );
      boss.receiveDamage(999);
      expect(
        boss.phase,
        CampaignChapterBossPhase.phaseThree,
        reason: 'phase three must complete an attack before defeat',
      );
      expect(boss.health, 1);
      _advanceUntilPhase(game, boss, CampaignChapterBossPhase.defeated);
      expect(boss.health, 0);

      expect(
        phaseChanges.where(
          (phase) => switch (phase) {
            CampaignChapterBossPhase.phaseOne ||
            CampaignChapterBossPhase.phaseTwo ||
            CampaignChapterBossPhase.phaseThree ||
            CampaignChapterBossPhase.defeated => true,
            _ => false,
          },
        ),
        <CampaignChapterBossPhase>[
          CampaignChapterBossPhase.phaseOne,
          CampaignChapterBossPhase.phaseTwo,
          CampaignChapterBossPhase.phaseThree,
          CampaignChapterBossPhase.defeated,
        ],
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

void _advanceUntilPhase(
  PatchWorldGame game,
  CampaignChapterBossComponent boss,
  CampaignChapterBossPhase target,
) {
  for (var tick = 0; tick < 180 && boss.phase != target; tick += 1) {
    _advanceSeconds(game, boss, 1 / 30);
  }
  expect(boss.phase, target, reason: 'boss did not reach ${target.name}');
}

void _advanceSeconds(
  PatchWorldGame game,
  CampaignChapterBossComponent boss,
  double seconds,
) {
  var remaining = seconds;
  while (remaining > 0) {
    final dt = remaining.clamp(0, 1 / 60).toDouble();
    game.clock.beginFrame(
      realDt: dt,
      simulationAdvances: true,
      enemySpeedMultiplier: 1,
    );
    boss.update(dt);
    remaining -= dt;
  }
}
