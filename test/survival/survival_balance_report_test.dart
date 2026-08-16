import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/survival/survival_balance_report.dart';

void main() {
  test('playtest records round-trip every balance signal', () {
    final record = _record(
      index: 7,
      weapon: PlayerWeapon.gun,
      completed: true,
      deathCauseId: 'enemy.arc_warden.radial',
      itemIds: const <String>{'railCapacitor', 'ricochetLens'},
    );

    final restored = SurvivalPlaytestRecord.fromJson(record.toJson());

    expect(restored.recordedAtEpochMs, 7);
    expect(restored.weapon, PlayerWeapon.gun);
    expect(restored.completed, isTrue);
    expect(restored.damageByCause, <String, int>{'enemy.arc_warden.radial': 2});
    expect(restored.patchIds, <String>{'patch.motion_tax'});
    expect(restored.itemIds, <String>{'railCapacitor', 'ricochetLens'});
    expect(restored.weaponBuildTiers, <String, int>{
      'survivalBuild.gunPrimary': 3,
    });
    expect(restored.metRegionEngagement, isTrue);
  });

  test('balanced five-run weapon samples pass statistical gates', () {
    final records = <SurvivalPlaytestRecord>[];
    var index = 0;
    const causes = <String>[
      'enemy.arc_warden.radial',
      'enemy.mine_layer.mine',
      'hazard.survival.reactorSpill',
    ];
    for (final weapon in PlayerWeapon.values) {
      for (var run = 0; run < 5; run += 1) {
        records.add(
          _record(
            index: index++,
            weapon: weapon,
            completed: run < 3,
            deathCauseId: causes[index % causes.length],
          ),
        );
      }
    }

    final report = SurvivalBalanceReport.fromRecords(records);

    expect(report.runCount, 15);
    expect(report.hasRequiredWeaponSamples, isTrue);
    expect(report.completionRateSpread, 0);
    expect(report.topDeathCauseShare, closeTo(1 / 3, .001));
    expect(report.passesCompletionParity, isTrue);
    expect(report.passesDeathCauseDiversity, isTrue);
    expect(report.passesRegionEngagement, isTrue);
    expect(report.statisticalGatesPassed, isTrue);
  });

  test('dominant weapon and death cause fail the tuning gates', () {
    final records = <SurvivalPlaytestRecord>[];
    var index = 0;
    for (final weapon in PlayerWeapon.values) {
      for (var run = 0; run < 5; run += 1) {
        records.add(
          _record(
            index: index++,
            weapon: weapon,
            completed: weapon == PlayerWeapon.sword,
            deathCauseId: 'enemy.rift_stalker.strike',
          ),
        );
      }
    }

    final report = SurvivalBalanceReport.fromRecords(records);

    expect(report.completionRateSpread, 1);
    expect(report.topDeathCauseShare, 1);
    expect(report.passesCompletionParity, isFalse);
    expect(report.passesDeathCauseDiversity, isFalse);
    expect(report.statisticalGatesPassed, isFalse);
  });

  test('item report exposes pick and completion rates', () {
    final report = SurvivalBalanceReport.fromRecords(<SurvivalPlaytestRecord>[
      _record(
        index: 1,
        weapon: PlayerWeapon.sword,
        completed: true,
        itemIds: const <String>{'phaseWhetstone', 'mirrorGuard'},
      ),
      _record(
        index: 2,
        weapon: PlayerWeapon.sword,
        completed: false,
        itemIds: const <String>{'mirrorGuard'},
      ),
    ]);

    final mirror = report.itemStats['mirrorGuard']!;
    expect(mirror.pickRate, 1);
    expect(mirror.completionRate, .5);
    expect(mirror.completedRunPickRate, 1);
    expect(report.strongestCompletionItem?.itemId, 'mirrorGuard');
    final build = report.buildStats['survivalBuild.swordPrimary']!;
    expect(build.pickRate, 1);
    expect(build.maxTierRate, 1);
    expect(build.completionRate, .5);
    expect(report.strongestCompletionBuild?.buildId, build.buildId);
    expect(report.topDamageSourceId, 'enemy.mine_layer.mine');
  });
}

SurvivalPlaytestRecord _record({
  required int index,
  required PlayerWeapon weapon,
  required bool completed,
  String deathCauseId = 'enemy.mine_layer.mine',
  Set<String> itemIds = const <String>{'mirrorGuard'},
}) => SurvivalPlaytestRecord(
  recordedAtEpochMs: index,
  weapon: weapon,
  elapsedSeconds: completed ? 1260 : 640,
  finalBossDefeated: completed,
  deathCauseId: deathCauseId,
  damageByCause: <String, int>{deathCauseId: 2},
  patchIds: const <String>{'patch.motion_tax'},
  itemIds: itemIds,
  weaponBuildTiers: <String, int>{'survivalBuild.${weapon.name}Primary': 3},
  completedWeaponBuilds: completed ? 2 : 1,
  visitedRegionCount: 3,
  regionEventsCompleted: 2,
  survivalBossesDefeated: completed ? 4 : 1,
);
