import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/survival/survival_balance_report.dart';
import 'package:patch_world/services/game_settings.dart';
import 'package:patch_world/services/settings_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  test('survival best score and time persist independently', () async {
    final service = SettingsService();
    await service.saveBestSurvivalScore(9001);
    await service.saveBestSurvivalTime(183.5);

    expect(await SettingsService().loadBestSurvivalScore(), 9001);
    expect(await SettingsService().loadBestSurvivalTime(), 183.5);
  });

  test('first-run language choice persists independently', () async {
    final service = SettingsService();
    final initial = await service.load();
    expect(initial.languageSetupComplete, isFalse);

    await service.save(
      const GameSettings(languageCode: 'ja', languageSetupComplete: true),
    );
    final restored = await SettingsService().load();
    expect(restored.languageCode, 'ja');
    expect(restored.languageSetupComplete, isTrue);
  });

  test('campaign abilities persist as survival choice unlocks', () async {
    final service = SettingsService();
    await service.saveSurvivalAbilityUnlocks(<CampaignTraversalAbility>{
      CampaignTraversalAbility.wallJump,
      CampaignTraversalAbility.terrainPulse,
    });

    expect(
      await SettingsService().loadSurvivalAbilityUnlocks(),
      <CampaignTraversalAbility>{
        CampaignTraversalAbility.wallJump,
        CampaignTraversalAbility.terrainPulse,
      },
    );
  });

  test('playtest history persists and keeps the latest ninety runs', () async {
    final records = List<SurvivalPlaytestRecord>.generate(
      95,
      (index) => SurvivalPlaytestRecord(
        recordedAtEpochMs: index,
        weapon: PlayerWeapon.values[index % PlayerWeapon.values.length],
        elapsedSeconds: 100 + index.toDouble(),
        finalBossDefeated: index.isEven,
        deathCauseId: 'enemy.test',
        damageByCause: const <String, int>{'enemy.test': 1},
        patchIds: const <String>{'patch.motion_tax'},
        itemIds: const <String>{'mirrorGuard'},
        weaponBuildTiers: const <String, int>{'survivalBuild.swordRiftEdge': 2},
        completedWeaponBuilds: 1,
        visitedRegionCount: 3,
        regionEventsCompleted: 2,
        survivalBossesDefeated: 1,
      ),
    );

    await SettingsService().saveSurvivalPlaytestRecords(records);
    final restored = await SettingsService().loadSurvivalPlaytestRecords();

    expect(restored, hasLength(SurvivalBalanceReport.maximumStoredRuns));
    expect(restored.first.recordedAtEpochMs, 5);
    expect(restored.last.recordedAtEpochMs, 94);
    expect(restored.last.itemIds, <String>{'mirrorGuard'});
  });
}
