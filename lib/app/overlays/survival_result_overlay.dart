import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';
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
                                'survivalResult.time',
                              ),
                              value: result.formattedTime,
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
                                'survivalResult.risk',
                              ),
                              value:
                                  'x${result.riskMultiplier.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
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
