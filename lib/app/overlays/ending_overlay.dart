import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class EndingOverlay extends StatelessWidget {
  const EndingOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xF2080B14),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'ACTIVE HUMAN PLAYERS: 1',
              style: TextStyle(
                color: Color(0xFF36E1FF),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'The machine wrote the rules.\n'
              'The human chose their meaning.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF4F7FF),
                fontSize: 30,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '기계는 규칙을 썼고, 인간은 그 의미를 선택했다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA9B4C8), fontSize: 16),
            ),
            const SizedBox(height: 36),
            FilledButton(
              onPressed: game.restartRun,
              child: const Text('PATCH AGAIN'),
            ),
          ],
        ),
      ),
    ),
  );
}
