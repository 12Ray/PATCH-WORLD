import 'package:flutter/material.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class PatchAppliedOverlay extends StatelessWidget {
  const PatchAppliedOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ValueListenableBuilder<PatchDefinition?>(
      valueListenable: game.patchNotice,
      builder: (context, patch, _) {
        if (patch == null) return const SizedBox.shrink();
        final localizedTitle = game.localization.text('${patch.id}.title');
        final localizedEffect = game.localization.text(
          '${patch.id}.sideEffect',
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 620,
            margin: const EdgeInsets.only(bottom: 22),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xEE111827),
              border: Border.all(color: const Color(0xFFFF4FD8), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  localizedTitle.startsWith('[') ? patch.title : localizedTitle,
                  style: const TextStyle(
                    color: Color(0xFF36E1FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localizedEffect.startsWith('[')
                      ? patch.sideEffect
                      : localizedEffect,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFF4F7FF)),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
