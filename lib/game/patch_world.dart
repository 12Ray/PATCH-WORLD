import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart' show FontWeight, TextStyle;
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/effects/retaliation_echo_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/room_one_controller.dart';

final class PatchWorld extends World with HasGameReference<PatchWorldGame> {
  late final PlayerComponent player;
  RoomOneController? _roomOne;

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
    await _loadRoomOne();
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

  Future<void> spawnRetaliationEcho(Vector2 worldPosition) async {
    final echoes = children.whereType<RetaliationEchoComponent>().toList(
      growable: false,
    );
    if (echoes.length >= 3) {
      echoes.first.removeFromParent();
    }
    await add(RetaliationEchoComponent(position: worldPosition));
  }

  Future<void> _loadRoomOne() async {
    final controller = RoomOneController();
    _roomOne = controller;
    await add(controller);
    player
      ..integrity = player.maxIntegrity
      ..position.setFrom(player.spawnPosition);
  }

  Future<void> restartCurrentRoom() async {
    final existing = _roomOne;
    if (existing != null) {
      existing.removeFromParent();
      await existing.removed;
    }
    for (final echo
        in children.whereType<RetaliationEchoComponent>().toList()) {
      echo.removeFromParent();
    }
    await _loadRoomOne();
  }

  Future<void> showPostPatchSandbox() async {
    await add(
      TextComponent(
        text: 'PATCH APPLIED — DAMAGE NORMALIZED',
        position: Vector2(480, 90),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF36E1FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        priority: 40,
      ),
    );
    await add(
      CrawlerComponent(
        entityId: 'post-patch-sandbox-target',
        position: Vector2(680, 270),
        initialHealth: CrawlerComponent.maxHealth,
      ),
    );
  }
}
