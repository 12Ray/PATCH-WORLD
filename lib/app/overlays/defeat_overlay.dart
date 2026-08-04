import 'package:flutter/material.dart';
import 'package:patch_world/game/core/run_metrics.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class DefeatOverlay extends StatelessWidget {
  const DefeatOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DefeatSnapshot?>(
    valueListenable: game.defeatSnapshot,
    builder: (context, defeat, _) {
      if (defeat == null) return const SizedBox.shrink();
      final localizedCause = game.localization.text('cause.${defeat.causeId}');
      return ColoredBox(
        color: const Color(0xEB080B14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      game.localization.text('defeat.title'),
                      style: const TextStyle(
                        color: Color(0xFFFF6464),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${game.localization.text('defeat.cause')}: '
                      '${localizedCause.startsWith('[') ? defeat.causeId : localizedCause}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFA9B4C8)),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        autofocus: true,
                        onPressed: game.restartDefeatedRoom,
                        child: Text(game.localization.text('ui.restartRoom')),
                      ),
                    ),
                    if (defeat.shouldOfferAssist) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        game.localization.text('defeat.assistPrompt'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: game.enableAssistAndRestart,
                        child: Text(
                          game.localization.text('defeat.enableAssist'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
