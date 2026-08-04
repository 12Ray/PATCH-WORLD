import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class CreditsOverlay extends StatelessWidget {
  const CreditsOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xF2080B14),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Material(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  game.localization.text('ui.credits'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  game.localization.text('credits.body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD7DEEC), height: 1.7),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: game.closeCredits,
                    child: Text(game.localization.text('ui.back')),
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
