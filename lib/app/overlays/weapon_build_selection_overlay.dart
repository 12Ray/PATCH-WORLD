import 'package:flutter/material.dart';
import 'package:patch_world/game/builds/weapon_build_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class WeaponBuildSelectionOverlay extends StatefulWidget {
  const WeaponBuildSelectionOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  State<WeaponBuildSelectionOverlay> createState() =>
      _WeaponBuildSelectionOverlayState();
}

final class _WeaponBuildSelectionOverlayState
    extends State<WeaponBuildSelectionOverlay> {
  WeaponBuildUpgradeId? _selected;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final request = game.pendingWeaponBuildSelection;
    if (request == null) return const SizedBox.shrink();
    return ColoredBox(
      color: const Color(0xF0050710),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final cards = request.choices
              .map(
                (upgrade) => _BuildCard(
                  game: game,
                  upgrade: upgrade,
                  currentTier: game.weaponBuild.tier(upgrade),
                  selected: _selected == upgrade,
                  onPressed: () {
                    if (_selected == upgrade) {
                      game.selectRoomOneBuildUpgrade(upgrade);
                    } else {
                      setState(() => _selected = upgrade);
                    }
                  },
                ),
              )
              .toList(growable: false);
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        game.localization.text('buildSelection.title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFF4F7FF),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        game.localization.text('buildSelection.subtitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB8C2D9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (compact)
                        ...cards.map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: card,
                          ),
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: cards
                              .map(
                                (card) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: card,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

final class _BuildCard extends StatelessWidget {
  const _BuildCard({
    required this.game,
    required this.upgrade,
    required this.currentTier,
    required this.selected,
    required this.onPressed,
  });

  final PatchWorldGame game;
  final WeaponBuildUpgradeId upgrade;
  final int currentTier;
  final bool selected;
  final VoidCallback onPressed;

  Color get accent => switch (upgrade.branch) {
    WeaponBuildBranch.mobility => const Color(0xFF36E1FF),
    WeaponBuildBranch.counter => const Color(0xFF45F3A6),
    WeaponBuildBranch.finisher => const Color(0xFFFF4FD8),
  };

  @override
  Widget build(BuildContext context) {
    final nextTier = currentTier + 1;
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 292),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? accent : const Color(0xFF35425E),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                game.localization.text('buildSelection.${upgrade.branch.name}'),
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                game.localization.text(upgrade.nameLocalizationKey),
                style: const TextStyle(
                  color: Color(0xFFF4F7FF),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                game.localization.text(
                  'buildSelection.tier',
                  parameters: <String, Object>{
                    'current': currentTier,
                    'next': nextTier,
                  },
                ),
                style: const TextStyle(
                  color: Color(0xFFFFD35A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 112,
                child: Text(
                  game.localization.text(upgrade.descriptionLocalizationKey),
                  style: const TextStyle(
                    color: Color(0xFFD7DEEC),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: selected ? accent : null,
                    foregroundColor: selected ? const Color(0xFF071019) : null,
                  ),
                  onPressed: onPressed,
                  child: Text(
                    game.localization.text(
                      selected
                          ? 'buildSelection.confirm'
                          : 'buildSelection.select',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
