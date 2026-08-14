import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/effects/data_shard_component.dart';
import 'package:patch_world/game/components/effects/data_surge_ring_component.dart';
import 'package:patch_world/game/components/effects/critical_flow_ring_component.dart';
import 'package:patch_world/game/components/effects/perfect_dodge_burst_component.dart';
import 'package:patch_world/game/components/effects/hound_break_burst_component.dart';
import 'package:patch_world/game/components/effects/phase_execution_burst_component.dart';
import 'package:patch_world/game/components/effects/retaliation_echo_component.dart';
import 'package:patch_world/game/components/effects/friendly_error_burst_component.dart';
import 'package:patch_world/game/components/effects/time_freeze_overlay_component.dart';
import 'package:patch_world/game/components/effects/survival_score_popup_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boot_sector_controller.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rooms/damage_lab_secret_controller.dart';
import 'package:patch_world/game/rooms/room_one_controller.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rooms/room_three_controller.dart';
import 'package:patch_world/game/rooms/room_two_controller.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/survival_crowd_separation.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';

final class PatchWorld extends World with HasGameReference<PatchWorldGame> {
  late final PlayerComponent player;
  Component? _activeRoom;
  CampaignNodeEntry _activeCampaignEntry = CampaignNodeEntry.west;
  bool _isReady = false;
  final List<SurvivalScorePopupComponent> _scorePopups =
      <SurvivalScorePopupComponent>[];
  TextComponent? _controlsHint;

  bool get isReady => _isReady;
  Component? get activeRoom => _activeRoom;
  Iterable<PositionComponent> get activeCombatTargets sync* {
    final room = _activeRoom;
    if (room == null) return;
    for (final child in room.children.whereType<PositionComponent>()) {
      if (child is CombatTarget && !child.isRemoving) yield child;
    }
  }

  Vector2 survivalCrowdSteering({
    required String entityId,
    required Vector2 position,
    required double separationRadius,
  }) {
    if (game.mode != PatchWorldMode.survival) return Vector2.zero();
    return SurvivalCrowdSeparation.steering(
      entityId: entityId,
      position: position,
      separationRadius: separationRadius,
      neighbors: activeCombatTargets.map(
        (target) => SurvivalCrowdNeighbor(
          entityId: (target as CombatTarget).entityId,
          position: target.position,
        ),
      ),
    );
  }

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
        )..configureLoadout(
          PlayerWeapon.sword,
          assistMode: game.settings.value.assistMode,
        );
    await add(player);
    await loadRoom(game.currentRoom);
    await add(TimeFreezeOverlayComponent());
    _controlsHint = TextComponent(
      text: game.localization.text('game.controlsHint'),
      position: Vector2(48, 66),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'PatchWorldCJK',
          color: Color(0xFF9CB0C9),
          fontSize: 14,
          letterSpacing: 1.1,
        ),
      ),
      priority: 40,
    );
    await add(_controlsHint!);
  }

  void refreshLocalizedText() {
    _controlsHint?.text = game.localization.text('game.controlsHint');
    final room = _activeRoom;
    if (room == null) return;
    for (final enemy in room.children.whereType<PlatformerEnemyComponent>()) {
      enemy.refreshLocalizedText();
    }
  }

  Future<void> loadRoom(RoomId roomId) async {
    final nextRoom = switch (roomId) {
      RoomId.bootSector => BootSectorController(),
      RoomId.damageLab => RoomOneController(progress: game.damageLabProgress),
      RoomId.temporalHall => RoomTwoController(
        progress: game.temporalHallProgress,
      ),
      RoomId.collisionArchive => RoomThreeController(
        progress: game.collisionArchiveProgress,
      ),
      RoomId.optimizerCore => BossRoomController(),
      RoomId.survivalArena => SurvivalArenaController(),
    };
    _activeCampaignEntry = CampaignNodeEntry.west;
    await _replaceActiveRoom(nextRoom);
  }

  Future<void> loadCampaignNode(
    CampaignNodeId nodeId, {
    required CampaignNodeEntry entry,
  }) async {
    final nextRoom = switch (nodeId) {
      CampaignNodeId.bootSector => BootSectorController(entry: entry),
      CampaignNodeId.damageWorkshop ||
      CampaignNodeId.damageAssembly ||
      CampaignNodeId.damageOverflow ||
      CampaignNodeId.overflowWarden => DamageLabNodeController(
        nodeId: nodeId,
        entry: entry,
        progress: game.damageLabProgress,
      ),
      CampaignNodeId.damageDashCache ||
      CampaignNodeId.damageUpperArchive ||
      CampaignNodeId.damageTurretControl => DamageLabSecretController(
        nodeId: nodeId,
        progress: game.damageLabProgress,
      ),
      CampaignNodeId.temporalAscent ||
      CampaignNodeId.temporalFracture ||
      CampaignNodeId.temporalPendulum ||
      CampaignNodeId.chronoJailer => RegionalCampaignNodeController(
        nodeId: nodeId,
        entry: entry,
        progress: game.temporalHallProgress,
      ),
      CampaignNodeId.collisionCompression ||
      CampaignNodeId.collisionFracture ||
      CampaignNodeId.collisionMerge ||
      CampaignNodeId.kernelChimera => RegionalCampaignNodeController(
        nodeId: nodeId,
        entry: entry,
        progress: game.collisionArchiveProgress,
      ),
      CampaignNodeId.optimizerCore => BossRoomController(),
    };
    _activeCampaignEntry = entry;
    await _replaceActiveRoom(nextRoom);
  }

  Future<void> _replaceActiveRoom(Component nextRoom) async {
    _isReady = false;
    final existing = _activeRoom;
    if (existing != null) {
      if (existing is BossRoomController) existing.disposeLegacyRule();
      final removed = existing.removed;
      existing.removeFromParent();
      if (existing.isMounted || existing.isRemoving) await removed;
    }
    for (final child in children.toList()) {
      if (child is RetaliationEchoComponent ||
          child is DataShardComponent ||
          child is SurvivalScorePopupComponent) {
        child.removeFromParent();
      }
    }
    _scorePopups.clear();
    _activeRoom = nextRoom;
    await add(nextRoom);
    final spawn = switch (nextRoom) {
      BootSectorController controller => controller.playerSpawn,
      DamageLabNodeController controller => controller.playerSpawn,
      DamageLabSecretController controller => controller.playerSpawn,
      RegionalCampaignNodeController controller => controller.playerSpawn,
      RoomOneController controller => controller.playerSpawn,
      RoomTwoController controller => controller.playerSpawn,
      RoomThreeController controller => controller.playerSpawn,
      BossRoomController controller => controller.playerSpawn,
      SurvivalArenaController controller => controller.playerSpawn,
      _ => throw StateError('Room controller does not expose a spawn.'),
    };
    player
      ..integrity = player.maxIntegrity
      ..resetMotionForRoomTransition()
      ..position.setFrom(spawn);
    _isReady = true;
    game.syncCampaignExploration();
  }

  bool tryInteract(PlayerComponent player) {
    final room = _activeRoom;
    return switch (room) {
      BootSectorController controller => controller.tryInteract(player),
      DamageLabNodeController controller => controller.tryInteract(player),
      DamageLabSecretController controller => controller.tryInteract(player),
      RegionalCampaignNodeController controller => controller.tryInteract(
        player,
      ),
      RoomOneController controller => controller.tryInteract(player),
      RoomTwoController controller => controller.tryInteract(player),
      RoomThreeController controller => controller.tryInteract(player),
      BossRoomController controller => controller.tryInteract(player),
      SurvivalArenaController _ => false,
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
    late final CrawlerComponent duplicate;
    duplicate = CrawlerComponent(
      entityId: '$sourceEntityId.echo',
      position: position + Vector2(38, 24),
      initialHealth: 1,
      healthMaximum: 1,
      canDuplicate: false,
      speedMultiplier: 1.15,
      onDefeated: game.mode == PatchWorldMode.survival
          ? () {
              final modifiers = game.survivalModifiers;
              game.recordSurvivalKillAt(
                duplicate.position,
                rewardMultiplier: modifiers.duplicateRewardMultiplier,
              );
              if (modifiers.duplicateBurstDamage > 0) {
                unawaited(
                  spawnFriendlyErrorBurst(
                    duplicate.position.clone(),
                    damage: modifiers.duplicateBurstDamage,
                    radius: modifiers.duplicateBurstRadius,
                    excludedEntityId: duplicate.entityId,
                  ),
                );
              }
            }
          : null,
    );
    await room.add(duplicate);
  }

  Future<void> restartCurrentRoom() {
    final room = _activeRoom;
    if (room is CampaignNodeRoom) {
      return loadCampaignNode(
        (room as CampaignNodeRoom).campaignNodeId,
        entry: _activeCampaignEntry,
      );
    }
    return loadRoom(game.currentRoom);
  }

  Future<void> spawnPatchPulse(
    Vector2 worldPosition, {
    int damage = 1,
    double radiusMultiplier = 1,
  }) async {
    await add(
      PatchPulseComponent(
        position: worldPosition.clone(),
        damage: damage,
        radiusMultiplier: radiusMultiplier,
      ),
    );
  }

  void spawnDataShards(
    Vector2 worldPosition, {
    required int count,
    bool corrupted = false,
    bool alternatingCorruption = true,
  }) {
    for (var index = 0; index < count; index += 1) {
      final angle = (index / count) * math.pi * 2 + (corrupted ? 0.35 : 0);
      add(
        DataShardComponent(
          position: worldPosition.clone(),
          scatterDirection: Vector2(math.cos(angle), math.sin(angle)),
          isCorrupted: corrupted || (alternatingCorruption && index.isOdd),
        ),
      );
    }
  }

  void spawnDataSurgeRing(Vector2 worldPosition) {
    add(DataSurgeRingComponent(position: worldPosition.clone()));
  }

  void spawnCriticalFlowRing(Vector2 worldPosition) {
    add(CriticalFlowRingComponent(position: worldPosition.clone()));
  }

  void spawnPerfectDodgeBurst(Vector2 worldPosition, {required int score}) {
    add(
      PerfectDodgeBurstComponent(
        position: worldPosition.clone(),
        score: score,
        label: game.localization.text('effect.perfectDodge'),
      ),
    );
  }

  void spawnHoundBreakBurst(Vector2 worldPosition, {required int score}) {
    add(
      HoundBreakBurstComponent(
        position: worldPosition.clone() + Vector2(0, -18),
        score: score,
        label: game.localization.text('effect.houndBreak'),
      ),
    );
  }

  void spawnPhaseExecutionBurst(Vector2 worldPosition, {required int score}) {
    add(
      PhaseExecutionBurstComponent(
        position: worldPosition.clone() + Vector2(0, -20),
        score: score,
        label: game.localization.text('effect.phaseExecution'),
        dataLabel: game.localization.text('hud.data'),
      ),
    );
  }

  void spawnSurvivalScorePopup(
    Vector2 worldPosition, {
    required int score,
    bool elite = false,
    bool miniBoss = false,
  }) {
    if (game.mode != PatchWorldMode.survival || score <= 0) return;
    _scorePopups.removeWhere((popup) => popup.isExpired || popup.isRemoving);
    while (_scorePopups.length >= 16) {
      _scorePopups.removeAt(0).removeFromParent();
    }
    final popup = SurvivalScorePopupComponent(
      position: worldPosition.clone(),
      score: score,
      kind: miniBoss
          ? SurvivalScorePopupKind.miniBoss
          : elite
          ? SurvivalScorePopupKind.elite
          : SurvivalScorePopupKind.normal,
    );
    _scorePopups.add(popup);
    add(popup);
  }

  Future<void> spawnRetaliationEcho(Vector2 worldPosition, int tier) async {
    final echoes = children.whereType<RetaliationEchoComponent>().toList(
      growable: false,
    );
    if (echoes.length >= 3) echoes.first.removeFromParent();
    await add(
      RetaliationEchoComponent(
        position: worldPosition,
        pullsTargets: tier >= 2,
        damage: tier >= 3 ? 2 : 1,
        damagesPlayer: tier < 3,
      ),
    );
  }

  Future<void> spawnFriendlyErrorBurst(
    Vector2 worldPosition, {
    required int damage,
    required double radius,
    String? excludedEntityId,
  }) async {
    await add(
      FriendlyErrorBurstComponent(
        position: worldPosition,
        damage: damage,
        blastRadius: radius,
        excludedEntityId: excludedEntityId,
      ),
    );
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
