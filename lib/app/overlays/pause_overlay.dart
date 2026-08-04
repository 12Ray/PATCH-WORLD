import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class PauseOverlay extends StatelessWidget {
  const PauseOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xB303050A),
    child: Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          border: Border.all(color: const Color(0xFF35425E)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'SYSTEM PAUSED',
              style: TextStyle(
                color: Color(0xFFF4F7FF),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: game.closePauseMenu,
                child: const Text('RESUME'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: game.restartRoomFromPauseMenu,
                child: const Text('RESTART ROOM'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Press Esc to continue',
              style: TextStyle(color: Color(0xFFA9B4C8)),
            ),
          ],
        ),
      ),
    ),
  );
}
