import 'package:flutter/material.dart';
import 'package:patch_world/app/overlays/choice_shortcut_badge.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_items.dart';

final class SurvivalItemRewardOverlay extends StatelessWidget {
  const SurvivalItemRewardOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) {
    final request = game.pendingSurvivalItemReward;
    if (request == null) return const SizedBox.shrink();
    return ColoredBox(
      color: const Color(0xF2050710),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    game.localization.text('survivalItemReward.title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF45F3A6),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    game.localization.text(request.source.localizationKey),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFA9B4C8)),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = request.choices
                          .asMap()
                          .entries
                          .map(
                            (entry) => _ItemCard(
                              game: game,
                              id: entry.value,
                              shortcutIndex: entry.key,
                              onSelected: () =>
                                  game.selectSurvivalItem(entry.value),
                            ),
                          )
                          .toList(growable: false);
                      if (constraints.maxWidth < 700) {
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
                  const SizedBox(height: 12),
                  Text(
                    game.localization.text(
                      'survivalItemReward.inventory',
                      parameters: <String, Object>{
                        'count': game.survivalItems.items.length,
                      },
                    ),
                    style: const TextStyle(
                      color: Color(0xFF7F8BA3),
                      fontSize: 12,
                    ),
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

final class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.game,
    required this.id,
    required this.shortcutIndex,
    required this.onSelected,
  });

  final PatchWorldGame game;
  final SurvivalItemId id;
  final int shortcutIndex;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final definition = SurvivalItemCatalog.definition(id);
    final accent = _accentFor(definition.weapon);
    final orderedTags = definition.tags.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 292),
          padding: const EdgeInsets.all(17),
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
                    definition.weapon == null
                        ? game.localization.text('survivalItemReward.shared')
                        : game.localization.text(
                            '${definition.weapon!.localizationKey}.name',
                          ),
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
                game.localization.text(
                  '${definition.localizationPrefix}.title',
                ),
                style: const TextStyle(
                  color: Color(0xFFF4F7FF),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 92),
                child: Text(
                  game.localization.text(
                    '${definition.localizationPrefix}.description',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFD7DEEC),
                    height: 1.42,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: orderedTags
                    .map(
                      (tag) => _TagChip(
                        game: game,
                        tag: tag,
                        projectedTier: _projectedTier(tag),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSelected,
                  child: Text(
                    game.localization.text('survivalItemReward.install'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _projectedTier(SurvivalItemTag tag) {
    final count = game.survivalItems.tagCount(tag) + 1;
    if (count >= 4) return 2;
    if (count >= 2) return 1;
    return 0;
  }

  Color _accentFor(PlayerWeapon? weapon) => switch (weapon) {
    PlayerWeapon.sword => const Color(0xFF36E1FF),
    PlayerWeapon.gauntlet => const Color(0xFFFF4FD8),
    PlayerWeapon.gun => const Color(0xFFFFC857),
    null => const Color(0xFF45F3A6),
  };
}

final class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.game,
    required this.tag,
    required this.projectedTier,
  });

  final PatchWorldGame game;
  final SurvivalItemTag tag;
  final int projectedTier;

  @override
  Widget build(BuildContext context) {
    final currentTier = game.survivalItems.synergyTier(tag);
    final activates = projectedTier > currentTier;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activates ? const Color(0x3345F3A6) : const Color(0x221F2937),
        border: Border.all(
          color: activates ? const Color(0xFF45F3A6) : const Color(0xFF46536B),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${game.localization.text(tag.localizationKey)} '
          '${game.survivalItems.tagCount(tag) + 1}/4'
          '${activates ? '  T$projectedTier' : ''}',
          style: TextStyle(
            color: activates
                ? const Color(0xFF8CFFD0)
                : const Color(0xFFA9B4C8),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
