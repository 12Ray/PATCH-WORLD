import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class PatchWorld extends World with HasGameReference<PatchWorldGame> {
  late final PlayerComponent player;

  bool _isReady = false;
  bool get isReady => _isReady;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await add(
      RectangleComponent(
        size: Vector2(
          PatchWorldGame.logicalWidth,
          PatchWorldGame.logicalHeight,
        ),
        paint: Paint()..color = const Color(0xFF0B1020),
        priority: -100,
      ),
    );
    await _addGrid();
    await _addBoundaryWalls();

    player = PlayerComponent(
      position: Vector2(160, 270),
      spawnPosition: Vector2(160, 270),
    );
    await add(player);
    await add(
      CrawlerComponent(
        entityId: 'crawler-debug-01',
        position: Vector2(700, 270),
      ),
    );
    await add(
      TextComponent(
        text: 'MOVE  WASD / ARROWS     PULSE  SPACE / J     PAUSE  ESC',
        position: Vector2(48, 42),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF9CB0C9),
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
        priority: 40,
      ),
    );

    _isReady = true;
  }

  Future<void> _addGrid() async {
    final gridPaint = Paint()
      ..color = const Color(0x122F6E5B)
      ..strokeWidth = 1;
    for (double x = 32; x < PatchWorldGame.logicalWidth; x += 32) {
      await add(
        RectangleComponent(
          position: Vector2(x, 0),
          size: Vector2(1, PatchWorldGame.logicalHeight),
          paint: gridPaint,
          priority: -90,
        ),
      );
    }
    for (double y = 32; y < PatchWorldGame.logicalHeight; y += 32) {
      await add(
        RectangleComponent(
          position: Vector2(0, y),
          size: Vector2(PatchWorldGame.logicalWidth, 1),
          paint: gridPaint,
          priority: -90,
        ),
      );
    }
  }

  Future<void> _addBoundaryWalls() async {
    const thickness = 24.0;
    const width = PatchWorldGame.logicalWidth;
    const height = PatchWorldGame.logicalHeight;
    await addAll(<WallComponent>[
      WallComponent(position: Vector2.zero(), size: Vector2(width, thickness)),
      WallComponent(
        position: Vector2(0, height - thickness),
        size: Vector2(width, thickness),
      ),
      WallComponent(position: Vector2.zero(), size: Vector2(thickness, height)),
      WallComponent(
        position: Vector2(width - thickness, 0),
        size: Vector2(thickness, height),
      ),
    ]);
  }

  Future<void> spawnPatchPulse(Vector2 worldPosition) async {
    await add(PatchPulseComponent(position: worldPosition.clone()));
  }
}
