import 'package:flutter/material.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class WeaponSelectionOverlay extends StatelessWidget {
  const WeaponSelectionOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xF2080B14),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    game.localization.text(
                      game.weaponSelectionForSurvival
                          ? 'survivalWeaponSelection.title'
                          : 'weaponSelection.title',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF36E1FF),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    game.localization.text(
                      game.weaponSelectionForSurvival
                          ? 'survivalWeaponSelection.subtitle'
                          : 'weaponSelection.subtitle',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFA9B4C8)),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: PlayerWeapon.values
                        .map(
                          (weapon) => SizedBox(
                            width: constraints.maxWidth < 650 ? 420 : 286,
                            child: _WeaponCard(game: game, weapon: weapon),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: game.cancelWeaponSelection,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(game.localization.text('ui.back')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _WeaponCard extends StatelessWidget {
  const _WeaponCard({required this.game, required this.weapon});

  final PatchWorldGame game;
  final PlayerWeapon weapon;

  @override
  Widget build(BuildContext context) {
    final key = weapon.localizationKey;
    final accent = switch (weapon) {
      PlayerWeapon.sword => const Color(0xFF36E1FF),
      PlayerWeapon.gauntlet => const Color(0xFFFF4FD8),
      PlayerWeapon.gun => const Color(0xFFFFC857),
    };
    final icon = switch (weapon) {
      PlayerWeapon.sword => Icons.auto_fix_high,
      PlayerWeapon.gauntlet => Icons.sports_mma,
      PlayerWeapon.gun => Icons.my_location,
    };
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 340),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: accent, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: accent, size: 36),
            const SizedBox(height: 8),
            Text(
              game.localization.text('$key.name'),
              style: TextStyle(
                color: accent,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              game.localization.text('$key.role'),
              style: const TextStyle(color: Color(0xFFA9B4C8), fontSize: 12),
            ),
            const SizedBox(height: 14),
            _StatLine(
              icon: Icons.favorite,
              label: game.localization.text('weaponSelection.health'),
              value: '${weapon.baseIntegrity}',
            ),
            _StatLine(
              icon: Icons.bolt,
              label: game.localization.text('weaponSelection.ability'),
              value: game.localization.text('$key.ability'),
            ),
            _StatLine(
              icon: Icons.speed,
              label: game.localization.text('weaponSelection.difficulty'),
              value: game.localization.text('$key.difficulty'),
            ),
            const SizedBox(height: 12),
            if (game.weaponSelectionForSurvival) ...<Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  game.localization.text('survivalWeaponSelection.buildHint'),
                  style: TextStyle(
                    color: accent,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                game.localization.text('$key.strength'),
                style: const TextStyle(
                  color: Color(0xFF45F3A6),
                  height: 1.35,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                game.localization.text('$key.weakness'),
                style: const TextStyle(
                  color: Color(0xFFFF8A8A),
                  height: 1.35,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: Key('weapon-select-${weapon.name}'),
                onPressed: () => game.selectStartingWeapon(weapon),
                child: Text(
                  game.localization.text(
                    'weaponSelection.choose',
                    parameters: <String, Object>{
                      'weapon': game.localization.text('$key.name'),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 15, color: const Color(0xFFA9B4C8)),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: const TextStyle(color: Color(0xFFA9B4C8), fontSize: 11),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFF4F7FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
