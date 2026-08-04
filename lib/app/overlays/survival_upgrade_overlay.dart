import 'package:flutter/material.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_patch_fusions.dart';

final class SurvivalUpgradeOverlay extends StatefulWidget {
  const SurvivalUpgradeOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  State<SurvivalUpgradeOverlay> createState() => _SurvivalUpgradeOverlayState();
}

final class _SurvivalUpgradeOverlayState extends State<SurvivalUpgradeOverlay> {
  PatchWorldGame get game => widget.game;

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
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const ValueKey<String>('survival-reroute'),
                        onPressed: game.canRerouteSurvivalUpgrade
                            ? () => setState(() {
                                game.rerouteSurvivalUpgrade();
                              })
                            : null,
                        icon: const Icon(Icons.shuffle, size: 16),
                        label: Text(
                          game.localization.text(
                            'survivalUpgrade.reroute',
                            parameters: <String, Object>{
                              'count': game.survivalRun.reroutesRemaining,
                            },
                          ),
                        ),
                      ),
                      Text(
                        game.localization.text(
                          game.canRerouteSurvivalUpgrade
                              ? 'survivalUpgrade.rerouteHint'
                              : 'survivalUpgrade.rerouteUnavailable',
                        ),
                        style: const TextStyle(
                          color: Color(0xFFA9B4C8),
                          fontSize: 11,
                        ),
                      ),
                    ],
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
    final fusion = SurvivalPatchFusions.definitionForPatch(patch.id);
    final fusionActive =
        fusion != null &&
        game.survivalModifiers.activeFusionIds.contains(fusion.id);
    final fusionReady = SurvivalPatchFusions.willUnlockAfterUpgrade(
      patchId: patch.id,
      nextTier: nextTier,
      patchTiers: game.survivalRun.patchTiers,
    );
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => game.selectSurvivalUpgrade(patch.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 300),
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
              _EffectSection(
                label: game.localization.text('survivalUpgrade.benefit'),
                color: const Color(0xFF36E1FF),
                body: _localizedTier('survivalBenefit', nextTier, patch.fix),
              ),
              const SizedBox(height: 12),
              _EffectSection(
                label: game.localization.text('survivalUpgrade.sideEffect'),
                color: const Color(0xFFFF4FD8),
                body: _localizedTier(
                  'survivalRisk',
                  nextTier,
                  patch.sideEffect,
                ),
              ),
              if (fusion != null && !fusionActive) ...<Widget>[
                const SizedBox(height: 12),
                _FusionHint(
                  ready: fusionReady,
                  label: game.localization.text(
                    fusionReady
                        ? 'survivalUpgrade.fusionReady'
                        : 'survivalUpgrade.fusionPath',
                  ),
                  body: fusionReady
                      ? game.localization.text('${fusion.id}.title')
                      : game.localization.text(
                          'survivalUpgrade.fusionRequirement',
                          parameters: <String, Object>{
                            'fusion': game.localization.text(
                              '${fusion.id}.title',
                            ),
                            'partner': game.localization.text(
                              '${fusion.partnerOf(patch.id)}.title',
                            ),
                          },
                        ),
                ),
              ],
              const SizedBox(height: 18),
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

  String _localizedTier(String field, int tier, String fallback) {
    final tierValue = game.localization.text('${patch.id}.$field.tier$tier');
    if (!tierValue.startsWith('[')) return tierValue;
    return _localized(field, fallback);
  }
}

final class _FusionHint extends StatelessWidget {
  const _FusionHint({
    required this.ready,
    required this.label,
    required this.body,
  });

  final bool ready;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ready ? const Color(0x22FFC857) : const Color(0x182D3B56),
      border: Border.all(
        color: ready ? const Color(0xFFFFC857) : const Color(0xFF596780),
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: ready ? const Color(0xFFFFC857) : const Color(0xFFA9B4C8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: const TextStyle(color: Color(0xFFF4F7FF), fontSize: 12),
        ),
      ],
    ),
  );
}

final class _EffectSection extends StatelessWidget {
  const _EffectSection({
    required this.label,
    required this.color,
    required this.body,
  });

  final String label;
  final Color color;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        body,
        style: const TextStyle(color: Color(0xFFD7DEEC), height: 1.35),
      ),
    ],
  );
}
