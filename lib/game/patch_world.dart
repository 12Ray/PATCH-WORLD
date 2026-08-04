import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/effects/retaliation_echo_component.dart';
import 'package:patch_world/game/components/effects/time_freeze_overlay_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/room_one_controller.dart';
import 'package:patch_world/game/rooms/room_two_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

final class PatchWorld extends World with HasGameReference<PatchWorldGame> {
  late final PlayerComponent player;
  Component? _activeRoom;
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
    await loadRoom(RoomId.damageLab);
    await add(TimeFreezeOverlayComponent());
    await add(
      TextComponent(
        text: 'MOVE  WASD / ARROWS     PULSE  SPACE / J     INTERACT  E',
        position: Vector2(48, 66),
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
  }

  Future<void> loadRoom(RoomId roomId) async {
    _isReady = false;
    final existing = _activeRoom;
    if (existing != null) {
      existing.removeFromParent();
      await existing.removed;
    }
    for (final child in children.toList()) {
      if (child is RetaliationEchoComponent) child.removeFromParent();
    }
    final nextRoom = switch (roomId) {
      RoomId.damageLab => RoomOneController(),
      RoomId.temporalHall => RoomTwoController(),
      RoomId.collisionArchive => throw UnimplementedError(
        'Room 3 is not loaded yet.',
      ),
      RoomId.optimizerCore => throw UnimplementedError(
        'Boss is not loaded yet.',
      ),
    };
    _activeRoom = nextRoom;
    await add(nextRoom);
    final spawn = switch (roomId) {
      RoomId.damageLab => Vector2(150, 270),
      RoomId.temporalHall => Vector2(110, 270),
      RoomId.collisionArchive => Vector2(110, 270),
      RoomId.optimizerCore => Vector2(480, 450),
    };
    player
      ..integrity = player.maxIntegrity
      ..position.setFrom(spawn);
    _isReady = true;
  }

  bool tryInteract(PlayerComponent player) {
    final room = _activeRoom;
    return room is RoomTwoController ? room.tryInteract(player) : false;
  }

  Future<void> restartCurrentRoom() => loadRoom(game.currentRoom);

  Future<void> spawnPatchPulse(Vector2 worldPosition) async {
    await add(PatchPulseComponent(position: worldPosition.clone()));
  }

  Future<void> spawnRetaliationEcho(Vector2 worldPosition) async {
    final echoes = children.whereType<RetaliationEchoComponent>().toList(
      growable: false,
    );
    if (echoes.length >= 3) echoes.first.removeFromParent();
    await add(RetaliationEchoComponent(position: worldPosition));
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
}
