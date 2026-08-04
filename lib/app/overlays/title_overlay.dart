import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/build_info.dart';
import 'package:patch_world/services/game_settings.dart';

final class TitleOverlay extends StatelessWidget {
  const TitleOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<GameSettings>(
    valueListenable: game.settings,
    builder: (context, settings, _) => DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/ui/patch_world_key_art.png'),
          fit: BoxFit.cover,
          opacity: 0.42,
        ),
      ),
      child: ColoredBox(
        color: const Color(0x99080B14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 420;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 10 : 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'PATCH//WORLD',
                        maxLines: 1,
                        style: TextStyle(
                          color: const Color(0xFF36E1FF),
                          fontSize: compact ? 27 : 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: compact ? 1.5 : 3,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 6),
                      Text(
                        game.localization.text('title.subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFF4FD8),
                          fontSize: compact ? 11 : 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 26),
                      if (!compact) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            border: Border.all(color: const Color(0xFF35425E)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            game.localization.text('title.controls'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD7DEEC),
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      SizedBox(
                        width: compact ? 220 : 300,
                        height: compact ? 34 : null,
                        child: FilledButton.icon(
                          autofocus: true,
                          onPressed: game.startRun,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(game.localization.text('ui.start')),
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 8),
                      SizedBox(
                        width: compact ? 220 : 300,
                        height: compact ? 34 : null,
                        child: OutlinedButton.icon(
                          onPressed: game.startSurvivalRun,
                          icon: const Icon(Icons.all_inclusive),
                          label: Text(game.localization.text('ui.survival')),
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 10),
                      Wrap(
                        spacing: compact ? 4 : 10,
                        runSpacing: 2,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: game.openSettingsFromTitle,
                            child: Text(game.localization.text('ui.settings')),
                          ),
                          OutlinedButton(
                            onPressed: game.openCreditsFromTitle,
                            child: Text(game.localization.text('ui.credits')),
                          ),
                        ],
                      ),
                      if (!compact) ...<Widget>[
                        const SizedBox(height: 18),
                        Text(
                          BuildInfo.label,
                          style: const TextStyle(
                            color: Color(0xFF6F7D96),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
