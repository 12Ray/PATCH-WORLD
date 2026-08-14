import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/build_info.dart';

final class PauseOverlay extends StatelessWidget {
  const PauseOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xB303050A),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            border: Border.all(color: const Color(0xFF35425E)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                game.localization.text('ui.pause'),
                style: const TextStyle(
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
                  child: Text(game.localization.text('ui.resume')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: game.openCreditsFromPause,
                  child: Text(game.localization.text('ui.credits')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: game.openSettings,
                  child: Text(game.localization.text('ui.settings')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: game.restartRoomFromPauseMenu,
                  child: Text(game.localization.text('ui.restartRoom')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: game.returnToTitle,
                  icon: const Icon(Icons.home_outlined),
                  label: Text(game.localization.text('summary.titleScreen')),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                game.localization.text('pause.hint'),
                style: const TextStyle(color: Color(0xFFA9B4C8)),
              ),
              const SizedBox(height: 8),
              Text(
                BuildInfo.label,
                style: const TextStyle(color: Color(0xFF6F7D96), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
