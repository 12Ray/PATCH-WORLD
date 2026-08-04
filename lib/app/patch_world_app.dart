import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/app/overlays/ending_overlay.dart';
import 'package:patch_world/app/overlays/hud_overlay.dart';
import 'package:patch_world/app/overlays/patch_selection_overlay.dart';
import 'package:patch_world/app/overlays/pause_overlay.dart';
import 'package:patch_world/app/overlays/settings_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/game_settings.dart';

final class PatchWorldApp extends StatefulWidget {
  const PatchWorldApp({super.key});

  @override
  State<PatchWorldApp> createState() => _PatchWorldAppState();
}

final class _PatchWorldAppState extends State<PatchWorldApp> {
  late final PatchWorldGame _game;

  @override
  void initState() {
    super.initState();
    _game = PatchWorldGame();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PATCH//WORLD',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05070D),
      ),
      builder: (context, child) => ValueListenableBuilder<GameSettings>(
        valueListenable: _game.settings,
        builder: (context, settings, _) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(settings.textScale)),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: AspectRatio(
            aspectRatio:
                PatchWorldGame.logicalWidth / PatchWorldGame.logicalHeight,
            child: ClipRect(
              child: GameWidget<PatchWorldGame>(
                game: _game,
                autofocus: true,
                initialActiveOverlays: const <String>[OverlayIds.hud],
                overlayBuilderMap:
                    <String, OverlayWidgetBuilder<PatchWorldGame>>{
                      OverlayIds.hud: (context, game) => HudOverlay(game: game),
                      OverlayIds.pause: (context, game) =>
                          PauseOverlay(game: game),
                      OverlayIds.ending: (context, game) =>
                          EndingOverlay(game: game),
                      OverlayIds.settings: (context, game) =>
                          SettingsOverlay(game: game),
                      OverlayIds.patchSelection: (context, game) =>
                          PatchSelectionOverlay(game: game),
                    },
                loadingBuilder: (context) => const _LoadingView(),
                errorBuilder: (context, error) => _ErrorView(error: error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF080B14),
      child: Center(child: CircularProgressIndicator(color: Color(0xFF45F3A6))),
    );
  }
}

final class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF080B14),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            '게임 초기화에 실패했습니다.\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
