import 'package:flutter/material.dart';
import 'package:patch_world/app/overlays/choice_shortcut_badge.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_weapon_build.dart';

final class SurvivalWeaponUpgradeOverlay extends StatelessWidget {
  const SurvivalWeaponUpgradeOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) {
    final request = game.pendingSurvivalWeaponUpgrade;
    if (request == null) return const SizedBox.shrink();
    final weapon = game.selectedRunWeapon ?? game.world.player.selectedWeapon;
    return ColoredBox(
      color: const Color(0xF203050A),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    game.localization.text(
                      'survivalBuild.title',
                      parameters: <String, Object>{
                        'level': request.level,
                        'weapon': game.localization.text(
                          '${weapon.localizationKey}.name',
                        ),
                      },
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    game.localization.text('survivalBuild.subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFA9B4C8)),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = request.choices
                          .asMap()
                          .entries
                          .map(
                            (entry) => _BuildCard(
                              game: game,
                              id: entry.value,
                              shortcutIndex: entry.key,
                              onSelected: () =>
                                  game.selectSurvivalWeaponUpgrade(entry.value),
                            ),
                          )
                          .toList(growable: false);
                      if (constraints.maxWidth < 680) {
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

final class _BuildCard extends StatelessWidget {
  const _BuildCard({
    required this.game,
    required this.id,
    required this.shortcutIndex,
    required this.onSelected,
  });

  final PatchWorldGame game;
  final SurvivalWeaponUpgradeId id;
  final int shortcutIndex;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final nextTier = game.survivalWeaponBuild.tier(id) + 1;
    final accent = switch (id.weapon) {
      PlayerWeapon.sword => const Color(0xFF36E1FF),
      PlayerWeapon.gauntlet => const Color(0xFFFF4FD8),
      PlayerWeapon.gun => const Color(0xFFFFC857),
    };
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 260),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'T$nextTier / T3',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  ChoiceShortcutBadge(index: shortcutIndex),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                game.localization.text('${id.id}.title'),
                style: const TextStyle(
                  color: Color(0xFFF4F7FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  game.localization.text('${id.id}.tier$nextTier'),
                  style: const TextStyle(
                    color: Color(0xFFD7DEEC),
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSelected,
                  child: Text(game.localization.text('survivalBuild.apply')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
