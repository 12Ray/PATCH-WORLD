import 'package:flutter/material.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_balance.dart';
import 'package:patch_world/game/survival/survival_balance_report.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';

final class SurvivalResultOverlay extends StatelessWidget {
  const SurvivalResultOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<SurvivalResultSnapshot?>(
    valueListenable: game.survivalResult,
    builder: (context, result, _) {
      if (result == null) return const SizedBox.shrink();
      final session = game.survivalSessionSummary;
      return ColoredBox(
        color: const Color(0xF2080B14),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Material(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFFF4FD8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          game.localization.text('survivalResult.title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFF6B8B),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          game.localization.text('survivalResult.subtitle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFA9B4C8)),
                        ),
                        if (result.isBestScore || result.isBestTime) ...[
                          const SizedBox(height: 12),
                          _BestBadge(
                            label: game.localization.text(
                              result.isBestScore
                                  ? 'survivalResult.newBestScore'
                                  : 'survivalResult.newBestTime',
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: <Widget>[
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.weapon',
                              ),
                              value: game.localization.text(
                                '${result.selectedWeapon.localizationKey}.name',
                              ),
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.time',
                              ),
                              value: result.formattedTime,
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.stage',
                              ),
                              value: game.localization.text(
                                result.difficultyStage.localizationKey,
                              ),
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.deathCause',
                              ),
                              value: game.localization.causeText(
                                result.deathCauseId,
                              ),
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.damageTaken',
                              ),
                              value: '${result.damageTaken}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.completedBuilds',
                              ),
                              value: '${result.completedWeaponBuilds}/3',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.regionsVisited',
                              ),
                              value: '${result.visitedRegionCount}/4',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.regionEvents',
                              ),
                              value:
                                  '${result.regionEventsCompleted}/${result.regionEventsStarted}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.bossesDefeated',
                              ),
                              value: '${result.survivalBossesDefeated}/4',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.finalBoss',
                              ),
                              value: game.localization.text(
                                result.finalBossDefeated
                                    ? 'survivalResult.defeated'
                                    : 'survivalResult.notReached',
                              ),
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.score',
                              ),
                              value: '${result.score}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.kills',
                              ),
                              value: '${result.kills}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.elites',
                              ),
                              value: '${result.eliteKills}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.miniBosses',
                              ),
                              value: '${result.miniBossKills}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.maxCombo',
                              ),
                              value: 'x${result.maxCombo}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.hotCaches',
                              ),
                              value:
                                  '${result.hotCachesCollected}/${result.hotCachesSpawned}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.perfectDodges',
                              ),
                              value: '${result.perfectDodges}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.houndBreaks',
                              ),
                              value: '${result.houndBreaks}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.phaseExecutions',
                              ),
                              value: '${result.phaseExecutions}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.risk',
                              ),
                              value:
                                  'x${result.riskMultiplier.toStringAsFixed(2)}',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.quietGap',
                              ),
                              value:
                                  '${result.longestQuietSeconds.toStringAsFixed(1)}s',
                            ),
                            _Stat(
                              label: game.localization.text(
                                'survivalResult.eventsPerMinute',
                              ),
                              value: result.eventsPerMinute.toStringAsFixed(1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _PacingBadge(
                          label: game.localization.text(
                            result.hasPacingGap
                                ? 'survivalResult.pacingGap'
                                : 'survivalResult.pacingClear',
                          ),
                          warning: result.hasPacingGap,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${game.localization.text('survivalResult.session')}  ${session.runCount}/5',
                          style: const TextStyle(
                            color: Color(0xFFA9B4C8),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (session.topPatchId case final String patchId) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${game.localization.text('survivalResult.topPick')}  ${game.localization.text('$patchId.title')}  ${(session.topPatchSelectionRate * 100).round()}%${session.hasSelectionBias ? '  // ${game.localization.text('survivalResult.selectionBias')}' : ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: session.hasSelectionBias
                                  ? const Color(0xFFFFC857)
                                  : const Color(0xFF45F3A6),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        if (session.topWeapon
                            case final PlayerWeapon weapon) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${game.localization.text('survivalResult.topWeapon')}  ${game.localization.text('${weapon.localizationKey}.name')}  ${(session.topWeaponSelectionRate * 100).round()}%${session.hasWeaponSelectionBias ? '  // ${game.localization.text('survivalResult.weaponSelectionBias')}' : ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: session.hasWeaponSelectionBias
                                  ? const Color(0xFFFFC857)
                                  : const Color(0xFF36E1FF),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        if (result.topDamageCauseId
                            case final String damageCauseId) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${game.localization.text('survivalResult.topDamageCause')}  ${game.localization.causeText(damageCauseId)}  ${result.damageByCause[damageCauseId]}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFF8A9A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _BalanceAudit(game: game),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            game.localization.text('survivalResult.patches'),
                            style: const TextStyle(
                              color: Color(0xFF45F3A6),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: result.patchTiers.isEmpty
                              ? Text(
                                  game.localization.text(
                                    'survivalResult.noPatches',
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF7F8BA3),
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: result.patchTiers.entries
                                      .map(
                                        (entry) => Chip(
                                          label: Text(
                                            '${game.localization.text('${entry.key}.title')}  T${entry.value}',
                                          ),
                                          backgroundColor: const Color(
                                            0xFF1B2638,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF45F3A6),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                        ),
                        if (result.activeFusionIds.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              game.localization.text('survivalResult.fusions'),
                              style: const TextStyle(
                                color: Color(0xFFFFC857),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: result.activeFusionIds
                                  .map(
                                    (fusionId) => Chip(
                                      label: Text(
                                        game.localization.text(
                                          '$fusionId.title',
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF332817),
                                      side: const BorderSide(
                                        color: Color(0xFFFFC857),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                        if (result.weaponBuildTiers.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              game.localization.text(
                                'survivalResult.weaponBuild',
                              ),
                              style: const TextStyle(
                                color: Color(0xFFFFC857),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: result.weaponBuildTiers.entries
                                  .map(
                                    (entry) => Chip(
                                      label: Text(
                                        '${game.localization.text('${entry.key}.title')}  T${entry.value}',
                                      ),
                                      backgroundColor: const Color(0xFF332817),
                                      side: const BorderSide(
                                        color: Color(0xFFFFC857),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                        if (result.itemIds.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              game.localization.text('survivalResult.items'),
                              style: const TextStyle(
                                color: Color(0xFF45F3A6),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: result.itemIds
                                  .map(
                                    (id) => Chip(
                                      label: Text(
                                        game.localization.text(
                                          'survivalItem.$id.title',
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF173329),
                                      side: const BorderSide(
                                        color: Color(0xFF45F3A6),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                        if (result.itemSynergyTiers.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              game.localization.text(
                                'survivalResult.itemSynergies',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF8CFFD0),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: result.itemSynergyTiers.entries
                                  .map(
                                    (entry) => Chip(
                                      label: Text(
                                        '${game.localization.text('survivalItemTag.${entry.key}')}  T${entry.value}',
                                      ),
                                      backgroundColor: const Color(0xFF173329),
                                      side: const BorderSide(
                                        color: Color(0xFF8CFFD0),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final vertical = constraints.maxWidth < 560;
                            final buttons = <Widget>[
                              FilledButton(
                                autofocus: true,
                                onPressed: game.retrySurvivalRun,
                                child: Text(
                                  game.localization.text(
                                    'survivalResult.retry',
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: result.firstPatchId == null
                                    ? null
                                    : () => game.retrySurvivalRun(
                                        keepStartingPatch: true,
                                      ),
                                child: Text(
                                  game.localization.text(
                                    'survivalResult.samePatch',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: game.returnToTitle,
                                child: Text(
                                  game.localization.text('summary.titleScreen'),
                                ),
                              ),
                            ];
                            if (vertical) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: buttons
                                    .expand(
                                      (button) => <Widget>[
                                        button,
                                        const SizedBox(height: 8),
                                      ],
                                    )
                                    .toList(growable: false),
                              );
                            }
                            return Row(
                              children: buttons
                                  .map(
                                    (button) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: button,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

final class _BalanceAudit extends StatelessWidget {
  const _BalanceAudit({required this.game});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) {
    final report = game.survivalBalanceReport;
    final statusKey =
        !report.hasRequiredWeaponSamples || !report.hasRequiredDeathSamples
        ? 'survivalResult.balanceCollecting'
        : report.statisticalGatesPassed
        ? 'survivalResult.balancePassed'
        : 'survivalResult.balanceTune';
    final statusColor = report.statisticalGatesPassed
        ? const Color(0xFF45F3A6)
        : const Color(0xFFFFC857);
    final topItem = report.strongestCompletionItem;
    final topBuild = report.strongestCompletionBuild;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        border: Border.all(color: const Color(0xFF36E1FF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  game.localization.text('survivalResult.balanceAudit'),
                  style: const TextStyle(
                    color: Color(0xFF36E1FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                game.localization.text(statusKey),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final weapon in PlayerWeapon.values)
                _AuditMetric(
                  label: game.localization.text(
                    '${weapon.localizationKey}.name',
                  ),
                  value:
                      '${report.weaponStats[weapon]!.runCount}/${SurvivalBalanceReport.minimumRunsPerWeapon}  ·  ${(report.weaponStats[weapon]!.completionRate * 100).round()}%',
                ),
              _AuditMetric(
                label: game.localization.text(
                  'survivalResult.balanceCompletionSpread',
                ),
                value: '${(report.completionRateSpread * 100).round()}% / 10%',
              ),
              _AuditMetric(
                label: game.localization.text(
                  'survivalResult.balanceTopDeathShare',
                ),
                value: report.topDeathCauseId == null
                    ? '0/${SurvivalBalanceReport.minimumDeathSamples}'
                    : '${(report.topDeathCauseShare * 100).round()}% / 35%',
              ),
              _AuditMetric(
                label: game.localization.text(
                  'survivalResult.balanceRegionEngagement',
                ),
                value: '${(report.regionEngagementRate * 100).round()}%',
              ),
            ],
          ),
          if (topItem != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '${game.localization.text('survivalResult.balanceTopItem')}  ${game.localization.text('survivalItem.${topItem.itemId}.title')}  ${(topItem.completedRunPickRate * 100).round()}% / ${(topItem.completionRate * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFF8CFFD0),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (topBuild != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '${game.localization.text('survivalResult.balanceTopBuild')}  ${game.localization.text('${topBuild.buildId}.title')}  ${(topBuild.completionRate * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFFFFD27A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (report.topDamageSourceId case final String causeId) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '${game.localization.text('survivalResult.balanceTopDamage')}  ${game.localization.causeText(causeId)}  ${report.damageCauseTotals[causeId]}',
              style: const TextStyle(
                color: Color(0xFFFF8A9A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _AuditMetric extends StatelessWidget {
  const _AuditMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$label  $value',
      style: const TextStyle(color: Color(0xFFD9E5F7), fontSize: 12),
    ),
  );
}

final class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: 118,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFF0B1220),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: <Widget>[
        Text(label, style: const TextStyle(color: Color(0xFF7F8BA3))),
        const SizedBox(height: 3),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

final class _BestBadge extends StatelessWidget {
  const _BestBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0x3345F3A6),
      border: Border.all(color: const Color(0xFF45F3A6)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF45F3A6),
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

final class _PacingBadge extends StatelessWidget {
  const _PacingBadge({required this.label, required this.warning});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFFFC857) : const Color(0xFF45F3A6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}
