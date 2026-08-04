import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/effects/data_shard_component.dart';
import 'package:patch_world/game/components/effects/retaliation_echo_component.dart';
import 'package:patch_world/game/components/effects/time_freeze_overlay_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/room_one_controller.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rooms/room_three_controller.dart';
import 'package:patch_world/game/rooms/room_two_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';

final class PatchWorld extends World with HasGameReference<PatchWorldGame> {
  late final PlayerComponent player;
  Component? _activeRoom;
  bool _isReady = false;

  bool get isReady => _isReady;
  Component? get activeRoom => _activeRoom;
  OptimizerBossComponent? get activeBoss {
    final room = _activeRoom;
    return room is BossRoomController ? room.boss : null;
  }

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
    player =
        PlayerComponent(
            position: Vector2(160, 270),
            spawnPosition: Vector2(160, 270),
          )
          ..maxIntegrity = game.settings.value.assistMode ? 6 : 5
          ..integrity = game.settings.value.assistMode ? 6 : 5;
    await add(player);
    await loadRoom(game.currentRoom);
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
      if (existing is BossRoomController) existing.disposeLegacyRule();
      existing.removeFromParent();
      await existing.removed;
    }
    for (final child in children.toList()) {
      if (child is RetaliationEchoComponent || child is DataShardComponent) {
        child.removeFromParent();
      }
    }
    final nextRoom = switch (roomId) {
      RoomId.damageLab => RoomOneController(),
      RoomId.temporalHall => RoomTwoController(),
      RoomId.collisionArchive => RoomThreeController(),
      RoomId.optimizerCore => BossRoomController(),
    };
    _activeRoom = nextRoom;
    await add(nextRoom);
    final spawn = switch (nextRoom) {
      RoomOneController controller => controller.playerSpawn,
      RoomTwoController controller => controller.playerSpawn,
      RoomThreeController controller => controller.playerSpawn,
      BossRoomController controller => controller.playerSpawn,
      _ => throw StateError('Room controller does not expose a spawn.'),
    };
    player
      ..integrity = player.maxIntegrity
      ..position.setFrom(spawn);
    _isReady = true;
  }

  bool tryInteract(PlayerComponent player) {
    final room = _activeRoom;
    return switch (room) {
      RoomTwoController controller => controller.tryInteract(player),
      RoomThreeController controller => controller.tryInteract(player),
      BossRoomController controller => controller.tryInteract(player),
      _ => false,
    };
  }

  bool tryMergeCrawlers(CrawlerComponent first, CrawlerComponent second) {
    final room = _activeRoom;
    return room is RoomThreeController ? room.tryMerge(first, second) : false;
  }

  bool isPulseBlocked(Vector2 from, Vector2 to) {
    final room = _activeRoom;
    if (room == null) return false;
    final blockers = <RectangleComponent>[
      ...room.children.whereType<WallComponent>(),
      ...room.children.whereType<PhaseWallComponent>().where(
        (wall) => wall.isSolid,
      ),
    ];
    return blockers.any(
      (wall) => _segmentIntersectsRectangle(from, to, wall.position, wall.size),
    );
  }

  bool get canSpawnProjectile {
    final room = _activeRoom;
    if (room == null) return false;
    return room.children.whereType<EnemyProjectileComponent>().length < 40;
  }

  Future<void> spawnDuplicate({
    required DuplicateArchetype archetype,
    required Vector2 position,
    required String sourceEntityId,
  }) async {
    final room = _activeRoom;
    if (room == null) return;
    final activeDuplicates = room.children
        .whereType<CrawlerComponent>()
        .where((crawler) => crawler.entityId.endsWith('.echo'))
        .length;
    if (activeDuplicates >= 6) return;
    await room.add(
      CrawlerComponent(
        entityId: '$sourceEntityId.echo',
        position: position + Vector2(38, 24),
        initialHealth: 1,
        healthMaximum: 1,
        canDuplicate: false,
        speedMultiplier: 1.15,
      ),
    );
  }

  Future<void> restartCurrentRoom() => loadRoom(game.currentRoom);

  Future<void> spawnPatchPulse(Vector2 worldPosition) async {
    await add(PatchPulseComponent(position: worldPosition.clone()));
  }

  void spawnDataShards(
    Vector2 worldPosition, {
    required int count,
    bool corrupted = false,
  }) {
    for (var index = 0; index < count; index += 1) {
      final angle = (index / count) * math.pi * 2 + (corrupted ? 0.35 : 0);
      add(
        DataShardComponent(
          position: worldPosition.clone(),
          scatterDirection: Vector2(math.cos(angle), math.sin(angle)),
          isCorrupted: corrupted || index.isOdd,
        ),
      );
    }
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

  bool _segmentIntersectsRectangle(
    Vector2 from,
    Vector2 to,
    Vector2 topLeft,
    Vector2 size,
  ) {
    var lower = 0.0;
    var upper = 1.0;
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final p = <double>[-dx, dx, -dy, dy];
    final q = <double>[
      from.x - topLeft.x,
      topLeft.x + size.x - from.x,
      from.y - topLeft.y,
      topLeft.y + size.y - from.y,
    ];
    for (var index = 0; index < 4; index += 1) {
      if (p[index] == 0) {
        if (q[index] < 0) return false;
        continue;
      }
      final ratio = q[index] / p[index];
      if (p[index] < 0) {
        lower = lower > ratio ? lower : ratio;
      } else {
        upper = upper < ratio ? upper : ratio;
      }
      if (lower > upper) return false;
    }
    return upper >= 0 && lower <= 1;
  }
}
