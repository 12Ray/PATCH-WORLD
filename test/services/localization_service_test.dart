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
      'objective.temporalSecret',
      'objective.collisionArchive',
      'objective.collisionSecret',
      'objective.optimizerPerfect',
      'interaction.enterDamageLab',
      'interaction.nextRoom',
      'interaction.enterBossRoom',
      'interaction.returnHubLift',
      'interaction.enterOptimizerCore',
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
