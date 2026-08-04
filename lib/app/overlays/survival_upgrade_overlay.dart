import 'package:flutter/material.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class SurvivalUpgradeOverlay extends StatelessWidget {
  const SurvivalUpgradeOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) {
    final request = game.pendingSurvivalUpgrade;
    if (request == null) return const SizedBox.shrink();
    return ColoredBox(
      color: const Color(0xED03050A),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    game.localization.text(
                      'survivalUpgrade.title',
                      parameters: <String, Object>{'level': request.level},
                    ),
                    style: const TextStyle(
                      color: Color(0xFFF4F7FF),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    game.localization.text('survivalUpgrade.subtitle'),
                    style: const TextStyle(color: Color(0xFFA9B4C8)),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = request.choices
                          .map(
                            (patch) => _UpgradeCard(game: game, patch: patch),
                          )
                          .toList(growable: false);
                      if (constraints.maxWidth < 660) {
                        return Column(
                          children: cards
                              .map(
                                (card) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: card,
                                ),
                              )
                              .toList(growable: false),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: cards
                            .map(
                              (card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: card,
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
    );
  }
}

final class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.game, required this.patch});

  final PatchWorldGame game;
  final PatchDefinition patch;

  @override
  Widget build(BuildContext context) {
    final nextTier = (game.survivalRun.patchTier(patch.id) + 1).clamp(1, 3);
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => game.selectSurvivalUpgrade(patch.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 230),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF36E1FF)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_localized('risk', patch.riskLabel)}  //  TIER $nextTier',
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _localized('title', patch.title),
                style: const TextStyle(
                  color: Color(0xFFF4F7FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _localized('sideEffect', patch.sideEffect),
                style: const TextStyle(color: Color(0xFFD7DEEC), height: 1.35),
              ),
              const Spacer(),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => game.selectSurvivalUpgrade(patch.id),
                  child: Text(game.localization.text('survivalUpgrade.apply')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localized(String field, String fallback) {
    final value = game.localization.text('${patch.id}.$field');
    return value.startsWith('[') ? fallback : value;
  }
}
