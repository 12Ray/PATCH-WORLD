import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/services/localization_service.dart';

void main() {
  testWidgets('Korean, English, and Japanese assets expose identical keys', (
    tester,
  ) async {
    final korean = LocalizationService();
    final english = LocalizationService();
    final japanese = LocalizationService();
    final fallback = LocalizationService();
    await korean.load('ko');
    await english.load('en');
    await japanese.load('ja');
    await fallback.load('fr');

    expect(korean.keys, english.keys);
    expect(japanese.keys, english.keys);
    expect(korean.text('ui.start'), isNot(startsWith('[')));
    expect(japanese.text('ui.start'), 'パッチ開始');
    expect(english.text('patch.duplicate_fault.sideEffect'), isNotEmpty);
    expect(fallback.languageCode, 'en');
    expect(fallback.text('ui.start'), 'START PATCHING');

    expect(
      LocalizationService.supportedLanguages
          .map((language) => '${language.code}:${language.nativeName}')
          .toList(growable: false),
      <String>['ko:한국어', 'en:English', 'ja:日本語'],
    );

    const criticalKeys = <String>[
      'ui.start',
      'weapon.sword.name',
      'weapon.gauntlet.name',
      'weapon.gun.name',
      'room.bootSector',
      'room.damageLab',
      'room.temporalHall',
      'room.temporalDashRift',
      'room.temporalUpperLoop',
      'room.temporalRelayControl',
      'room.collisionArchive',
      'room.collisionVectorCache',
      'room.collisionUpperMatrix',
      'room.collisionPrismControl',
      'room.optimizerCore',
      'objective.bootSector',
      'objective.damageLab',
      'objective.temporalHall',
      'objective.temporalAscentTask',
      'objective.temporalFractureTask',
      'objective.temporalPendulumTask',
      'objective.temporalSecret',
      'objective.collisionArchive',
      'objective.collisionCompressionTask',
      'objective.collisionFractureTask',
      'objective.collisionMergeTask',
      'objective.collisionSecret',
      'objective.roomTaskComplete',
      'objective.optimizerPerfect',
      'interaction.enterDamageLab',
      'interaction.nextRoom',
      'interaction.enterBossRoom',
      'interaction.returnHubLift',
      'interaction.enterOptimizerCore',
      'interaction.clearThreats',
      'interaction.completeRoomTask',
      'interaction.completePreviousRooms',
      'interaction.objectiveNodeSynced',
      'interaction.syncClockAnchor',
      'interaction.linkEchoRelay',
      'interaction.releaseRewindLock',
      'interaction.releasePressureValve',
      'interaction.alignPhaseShard',
      'interaction.balancePolarityCoil',
      'interaction.enterTemporalDashRift',
      'interaction.enterTemporalUpperLoop',
      'interaction.enterTemporalRelayControl',
      'interaction.enterCollisionVectorCache',
      'interaction.enterCollisionUpperMatrix',
      'interaction.enterCollisionPrismControl',
      'interaction.returnTemporalFracture',
      'interaction.returnCollisionFracture',
      'boss.overflowWarden.intro',
      'boss.chronoJailer.intro',
      'boss.kernelChimera.intro',
      'boss.optimizer.name',
      'boss.optimizer.intro',
      'boss.coreSignatureAcquired',
      'hud.integrity',
      'hud.bossHealth',
      'hud.bossStability',
      'item.overflowCapacitor.name',
      'item.temporalRelay.name',
      'item.collisionPrism.name',
      'item.chronalBuffer.name',
      'item.echoSpring.name',
      'item.predictiveScope.name',
      'item.vectorEdge.name',
      'item.impactLattice.name',
      'item.splitChamber.name',
      'item.bladeCalibrator.name',
      'item.bladeCalibrator.description',
      'item.impactCalibrator.name',
      'item.impactCalibrator.description',
      'item.barrelCalibrator.name',
      'item.barrelCalibrator.description',
      'item.afterimageGovernor.name',
      'item.afterimageGovernor.description',
      'item.echoLiftServo.name',
      'item.echoLiftServo.description',
      'item.forecastTrigger.name',
      'item.forecastTrigger.description',
      'item.momentumEdge.name',
      'item.momentumEdge.description',
      'item.seismicCoupler.name',
      'item.seismicCoupler.description',
      'item.prismBore.name',
      'item.prismBore.description',
      'itemDiscovery.loadoutEvent',
      'itemDiscovery.duplicateConverted',
      'itemDiscovery.duplicateIntegrity',
    ];
    const parameters = <String, Object>{
      'room': 1,
      'cleared': 3,
      'records': 3,
      'stability': 150,
      'boss': 'BOSS',
      'phase': 'PHASE 3',
      'current': 6,
      'max': 24,
      'perfect': 'PERFECT',
      'value': 150,
      'objective': 3,
      'total': 3,
      'defeated': 4,
      'enemies': 4,
      'time': 9,
      'item': 'MODULE',
    };

    for (final entry in <(String, LocalizationService)>[
      ('ko', korean),
      ('en', english),
      ('ja', japanese),
    ]) {
      final code = entry.$1;
      final service = entry.$2;
      for (final key in criticalKeys) {
        final value = service.text(key, parameters: parameters);
        expect(value.trim(), isNotEmpty, reason: '$code: $key');
        expect(value, isNot(startsWith('[')), reason: '$code: missing $key');
        expect(
          value,
          isNot(contains('\uFFFD')),
          reason: '$code: broken UTF-8 in $key',
        );
        expect(
          RegExp(r'\{[^}]+\}').hasMatch(value),
          isFalse,
          reason: '$code: unresolved parameter in $key',
        );
      }
    }
  });
}
