import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_pattern_catalog.dart';

void main() {
  group('campaign chapter boss pattern contract', () {
    test('each boss owns five unique and fully timed attacks', () {
      for (final set in <CampaignChapterBossPatternSet>[
        CampaignChapterBossPatternCatalog.chronoJailer,
        CampaignChapterBossPatternCatalog.kernelChimera,
      ]) {
        expect(set.patterns, hasLength(5));
        expect(set.patterns.map((pattern) => pattern.id).toSet(), hasLength(5));
        for (final pattern in set.patterns) {
          expect(pattern.telegraphSeconds, greaterThan(0));
          expect(pattern.activeSeconds, greaterThan(0));
          expect(pattern.recoverySeconds, greaterThan(0));
          expect(pattern.attackSpace, isNotEmpty);
          expect(pattern.movement, isNotEmpty);
          expect(pattern.counterplay, isNotEmpty);
        }
      }
    });

    test(
      'Chrono and Kernel expose different spatial gameplay fingerprints',
      () {
        final chrono = CampaignChapterBossPatternCatalog.chronoJailer;
        final kernel = CampaignChapterBossPatternCatalog.kernelChimera;

        expect(chrono.fingerprint, isNot(kernel.fingerprint));
        expect(chrono.fingerprint, contains('clock'));
        expect(chrono.fingerprint, contains('rewind'));
        expect(kernel.fingerprint, contains('split'));
        expect(kernel.fingerprint, contains('polarity'));
        expect(kernel.fingerprint, contains('merge'));
        expect(
          chrono.patterns
              .map((pattern) => pattern.id)
              .toSet()
              .intersection(
                kernel.patterns.map((pattern) => pattern.id).toSet(),
              ),
          isEmpty,
        );
      },
    );

    test('visual timeline preserves active and recovery after execution', () {
      final attack = CampaignChapterBossPatternCatalog.chronoJailer.byId(
        'clockSweep',
      );
      final cycle = CampaignBossAttackCycle();

      expect(cycle.start(attack), isTrue);
      expect(cycle.phase, CampaignBossAttackVisualPhase.telegraph);
      expect(cycle.attack?.id, 'clockSweep');

      final executeEvents = cycle.advance(attack.telegraphSeconds);
      expect(executeEvents, <CampaignBossAttackCycleEvent>[
        CampaignBossAttackCycleEvent.execute,
      ]);
      expect(cycle.phase, CampaignBossAttackVisualPhase.active);
      expect(cycle.attack?.id, 'clockSweep');
      expect(
        campaignBossHasLiveExecutionWindow(executeEvents, cycle.phase),
        isTrue,
      );

      expect(
        cycle.advance(attack.activeSeconds),
        <CampaignBossAttackCycleEvent>[
          CampaignBossAttackCycleEvent.activeEnded,
        ],
      );
      expect(cycle.phase, CampaignBossAttackVisualPhase.recovery);
      expect(cycle.attack?.id, 'clockSweep');

      expect(
        cycle.advance(attack.recoverySeconds),
        <CampaignBossAttackCycleEvent>[CampaignBossAttackCycleEvent.recovered],
      );
      expect(cycle.phase, CampaignBossAttackVisualPhase.idle);
      expect(cycle.attack, isNull);
    });

    test('visual phases resolve to the Art v3 signature frame contract', () {
      expect(
        resolveCampaignBossAttackFrame(CampaignBossAttackVisualPhase.idle, 0),
        -1,
      );
      expect(
        resolveCampaignBossAttackFrame(
          CampaignBossAttackVisualPhase.telegraph,
          0,
        ),
        4,
      );
      expect(
        resolveCampaignBossAttackFrame(CampaignBossAttackVisualPhase.active, 0),
        5,
      );
      expect(
        <int>{
          resolveCampaignBossAttackFrame(
            CampaignBossAttackVisualPhase.recovery,
            0,
          ),
          resolveCampaignBossAttackFrame(
            CampaignBossAttackVisualPhase.recovery,
            .1,
          ),
        },
        <int>{6, 7},
      );
    });

    test(
      'large delta emits every lifecycle event once without getting stuck',
      () {
        final attack = CampaignChapterBossPatternCatalog.kernelChimera.byId(
          'mergeSlam',
        );
        final cycle = CampaignBossAttackCycle();
        cycle.start(attack);

        final skippedEvents = cycle.advance(120);
        expect(skippedEvents, <CampaignBossAttackCycleEvent>[
          CampaignBossAttackCycleEvent.execute,
          CampaignBossAttackCycleEvent.activeEnded,
          CampaignBossAttackCycleEvent.recovered,
        ]);
        expect(cycle.phase, CampaignBossAttackVisualPhase.idle);
        expect(cycle.remaining, 0);
        expect(
          campaignBossHasLiveExecutionWindow(skippedEvents, cycle.phase),
          isFalse,
          reason: 'a skipped active window must not materialize fresh hazards',
        );
        expect(cycle.advance(120), isEmpty);
      },
    );

    test('zero and invalid clock deltas cannot advance an attack', () {
      final attack = CampaignChapterBossPatternCatalog.kernelChimera.byId(
        'splitKernel',
      );
      final cycle = CampaignBossAttackCycle();
      cycle.start(attack);

      expect(cycle.advance(0), isEmpty);
      expect(cycle.advance(double.infinity), isEmpty);
      expect(cycle.phase, CampaignBossAttackVisualPhase.telegraph);
      expect(cycle.remaining, attack.telegraphSeconds);
      expect(cycle.start(attack), isFalse);
    });
  });
}
