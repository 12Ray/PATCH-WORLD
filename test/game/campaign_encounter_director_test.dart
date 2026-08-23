import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_encounter_contract.dart';
import 'package:patch_world/game/campaign/campaign_encounter_director.dart';

void main() {
  const spec = CampaignEncounterSpec(
    triggerZone: Rect.fromLTWH(300, 200, 100, 300),
    waves: <CampaignEncounterWaveSpec>[
      CampaignEncounterWaveSpec(enemyIds: <String>['alpha', 'beta']),
      CampaignEncounterWaveSpec(enemyIds: <String>['gamma']),
    ],
    intermissionSeconds: 1.2,
    sealSeconds: .4,
    clearBeatSeconds: .8,
    maxActiveEnemies: 2,
    combatCamera: CampaignCombatCameraSpec(
      zone: Rect.fromLTWH(200, 100, 500, 400),
      zoom: .82,
    ),
  );

  test('runs seal, waves, intermission and clear beat in authored order', () {
    final activations = <(int, List<String>)>[];
    final phases = <CampaignEncounterPhase>[];
    var clearCount = 0;
    final director = CampaignEncounterDirector(
      spec: spec,
      onWaveActivated: (index, ids) => activations.add((index, ids)),
      onClearBeatStarted: () {},
      onCleared: () => clearCount += 1,
      onPhaseChanged: phases.add,
    );

    expect(director.tryTrigger(const Offset(20, 20)), isFalse);
    expect(director.phase, CampaignEncounterPhase.idle);
    expect(director.tryTrigger(const Offset(350, 350)), isTrue);
    expect(director.isSealed, isTrue);
    expect(director.phase, CampaignEncounterPhase.sealing);

    director.update(.4);
    expect(director.phase, CampaignEncounterPhase.wave);
    expect(director.activeEnemyIds, <String>{'alpha', 'beta'});
    expect(activations.single.$1, 0);

    expect(director.notifyEnemyDefeated('gamma'), isFalse);
    expect(director.notifyEnemyDefeated('alpha'), isTrue);
    expect(director.phase, CampaignEncounterPhase.wave);
    expect(director.notifyEnemyDefeated('beta'), isTrue);
    expect(director.phase, CampaignEncounterPhase.intermission);

    director.update(1.2);
    expect(director.phase, CampaignEncounterPhase.wave);
    expect(director.waveIndex, 1);
    expect(director.activeEnemyIds, <String>{'gamma'});

    expect(director.notifyEnemyDefeated('gamma'), isTrue);
    expect(director.phase, CampaignEncounterPhase.clearBeat);
    expect(director.isSealed, isTrue);
    director.update(.8);
    expect(director.phase, CampaignEncounterPhase.cleared);
    expect(director.isSealed, isFalse);
    expect(clearCount, 1);
    expect(phases, <CampaignEncounterPhase>[
      CampaignEncounterPhase.sealing,
      CampaignEncounterPhase.wave,
      CampaignEncounterPhase.intermission,
      CampaignEncounterPhase.wave,
      CampaignEncounterPhase.clearBeat,
      CampaignEncounterPhase.cleared,
    ]);
  });

  test('a cleared revisit cannot retrigger or activate enemies', () {
    var activationCount = 0;
    final director = CampaignEncounterDirector(
      spec: spec,
      initiallyCleared: true,
      onWaveActivated: (_, _) => activationCount += 1,
      onClearBeatStarted: () => fail('A cleared revisit must not present.'),
      onCleared: () => fail('A cleared revisit must not clear again.'),
    );

    expect(director.isCleared, isTrue);
    expect(director.tryTrigger(const Offset(350, 350)), isFalse);
    director.update(99);
    expect(activationCount, 0);
  });

  test('large real-time updates stop when a wave becomes active', () {
    final director = CampaignEncounterDirector(
      spec: spec,
      onWaveActivated: (_, _) {},
      onClearBeatStarted: () {},
      onCleared: () {},
    );

    director.tryTrigger(const Offset(350, 350));
    director.update(20);
    expect(director.phase, CampaignEncounterPhase.wave);
    expect(director.waveIndex, 0);
  });

  test('east entry activates authored waves in reverse spatial order', () {
    final activations = <List<String>>[];
    final director = CampaignEncounterDirector(
      spec: spec,
      reverseWaves: true,
      onWaveActivated: (_, ids) => activations.add(ids),
      onClearBeatStarted: () {},
      onCleared: () {},
    );

    director.tryTrigger(const Offset(350, 350));
    director.update(.4);
    expect(activations.single, <String>['gamma']);
  });

  test('holds the seal after combat until a room objective is complete', () {
    var clearBeatCount = 0;
    final director = CampaignEncounterDirector(
      spec: spec,
      completionGateSatisfied: false,
      onWaveActivated: (_, _) {},
      onClearBeatStarted: () => clearBeatCount += 1,
      onCleared: () {},
    );

    director.tryTrigger(const Offset(350, 350));
    director.update(.4);
    director.notifyEnemyDefeated('alpha');
    director.notifyEnemyDefeated('beta');
    director.update(1.2);
    director.notifyEnemyDefeated('gamma');

    expect(director.phase, CampaignEncounterPhase.objectiveHold);
    expect(director.isSealed, isTrue);
    director.update(99);
    expect(director.phase, CampaignEncounterPhase.objectiveHold);

    director.notifyCompletionGateSatisfied();
    expect(director.phase, CampaignEncounterPhase.clearBeat);
    expect(clearBeatCount, 1);
    director.update(.8);
    expect(director.phase, CampaignEncounterPhase.cleared);
  });

  group('CampaignEncounterSpecValidator trigger zone', () {
    const roomBounds = Rect.fromLTWH(0, 0, 800, 600);
    const westEntry = Offset(80, 300);
    const eastEntry = Offset(720, 300);
    const enemyPositions = <String, Offset>{
      'alpha': Offset(250, 300),
      'beta': Offset(550, 300),
    };

    CampaignEncounterSpec encounterWith(Rect triggerZone) =>
        CampaignEncounterSpec(
          triggerZone: triggerZone,
          waves: const <CampaignEncounterWaveSpec>[
            CampaignEncounterWaveSpec(enemyIds: <String>['alpha']),
            CampaignEncounterWaveSpec(enemyIds: <String>['beta']),
          ],
          intermissionSeconds: 1,
          sealSeconds: .4,
          clearBeatSeconds: .8,
          maxActiveEnemies: 1,
          combatCamera: const CampaignCombatCameraSpec(
            zone: roomBounds,
            zoom: .82,
          ),
        );

    List<String> validate(Rect triggerZone) =>
        CampaignEncounterSpecValidator.validate(
          encounter: encounterWith(triggerZone),
          roomLabel: 'test room',
          roomBounds: roomBounds,
          enemyPositions: enemyPositions,
          westEntry: westEntry,
          eastEntry: eastEntry,
        );

    test('accepts a full-height barrier between both entries', () {
      expect(validate(const Rect.fromLTWH(300, 0, 100, 600)), isEmpty);
    });

    test('rejects a vertically bypassable zone despite valid entry x', () {
      final errors = validate(const Rect.fromLTWH(300, 250, 100, 100));

      expect(
        errors,
        contains(
          'test room encounter triggerZone must span the room playable height '
          'so it cannot be bypassed vertically',
        ),
      );
      expect(
        errors,
        isNot(
          contains(
            'test room encounter triggerZone must lie between west/east entry '
            'spawns for bidirectional entry',
          ),
        ),
      );
    });

    test('rejects gaps at either playable vertical boundary', () {
      expect(
        validate(const Rect.fromLTWH(300, 1, 100, 599)),
        contains(contains('must span the room playable height')),
      );
      expect(
        validate(const Rect.fromLTWH(300, 0, 100, 599)),
        contains(contains('must span the room playable height')),
      );
    });
  });
}
