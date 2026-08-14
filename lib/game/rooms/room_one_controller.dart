import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/campaign/damage_lab_floor_state.dart';
import 'package:patch_world/game/components/boss/overflow_warden_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/qa_record_terminal_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/items/item_pedestal_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/presentation/item_discovery_presentation_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/rooms/damage_lab_room_status.dart';
import 'package:patch_world/game/rules/rule_context.dart';

final class RoomOneController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        DamageLabRoomStatus {
  RoomOneController({required this.progress});

  static const double cellWidth = 960;
  static const int encounterCount = 3;

  final DamageLabFloorState progress;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  final Map<PlatformerEnemyComponent, int> _enemyEncounterIds =
      <PlatformerEnemyComponent, int>{};
  final Set<PlatformerEnemyComponent> _defeatedEnemies =
      <PlatformerEnemyComponent>{};
  final List<BossSealGateComponent> _encounterGates = <BossSealGateComponent>[];
  final List<QaRecordTerminalComponent> _recordTerminals =
      <QaRecordTerminalComponent>[];

  OverflowWardenBossComponent? _boss;
  ItemPedestalComponent? _questReward;
  ItemPedestalComponent? _bossReward;
  _PatchExitTerminalComponent? _exitTerminal;
  CampaignDoorComponent? _hubDoor;
  TextComponent? _bossBanner;
  Vector2 _respawnPoint = Vector2(72, 988);
  int _currentCell = 0;
  int _defeatedCount = 0;
  double _bossIntroRemaining = 0;
  bool _bossEncounterStarted = false;
  bool _patchSelectionOpened = false;

  @override
  Vector2 get playerSpawn {
    final cell = progress.resumeCell;
    return Vector2(cell * cellWidth + 72, 988);
  }

  @override
  final Vector2 worldSize = Vector2(cellWidth * 4, 1080);

  @override
  double get killPlaneY => 1160;

  int get overflowCount => _defeatedCount;
  int get defeatedCount => _defeatedCount;
  @override
  int get clearedEncounterCount => progress.clearedEncounterCount;
  @override
  int get qaRecordCount => progress.collectedRecordCount;
  @override
  int get currentCellNumber => (_currentCell + 1).clamp(1, 4);
  @override
  bool get isCompleted => progress.bossDefeated;
  bool get isBossIntroActive => _bossIntroRemaining > 0;
  @override
  int? get bossHealth => _bossEncounterStarted ? _boss?.health : null;
  @override
  int? get bossMaxHealth =>
      _bossEncounterStarted ? _boss?.maximumOverflowHealth : null;
  @override
  String? get bossPhaseKey => _bossEncounterStarted ? _boss?.phaseId : null;

  @override
  Iterable<Rect> get solidBounds => _surfaces
      .where((surface) => surface.isSolid)
      .map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) => _respawnPoint.clone();

  @override
  Vector2 cameraTargetFor(Vector2 playerPosition) {
    final targetCell = isBossIntroActive
        ? 3
        : (playerPosition.x / cellWidth).floor().clamp(0, 3);
    final centerX = targetCell * cellWidth + cellWidth / 2;
    final centerY = playerPosition.y.clamp(270, 810).toDouble();
    return Vector2(centerX, isBossIntroActive ? 790 : centerY);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _respawnPoint = playerSpawn;
    _currentCell = progress.resumeCell;
    await add(
      RoomBackdropComponent(RoomBackdropStyle.damage, worldSize: worldSize),
    );
    _buildGeometry();
    await addAll(_surfaces);
    await _addHazardsAndTraversal();
    final hubDoor = CampaignDoorComponent(
      position: Vector2(72, 1024),
      labelLocalizationKey: 'interaction.returnBootSector',
      onInteract: () => game.travelToCampaignRoom(RoomId.bootSector),
      accentColor: const Color(0xFF9D8CFF),
    );
    _hubDoor = hubDoor;
    await add(hubDoor);
    await _addEncounters();
    await _addOptionalQuest();
    await _addBossRoom();
    _synchronizeGateState();
  }

  void _buildGeometry() {
    _encounterGates.addAll(<BossSealGateComponent>[
      for (var index = 1; index <= 3; index += 1)
        BossSealGateComponent(
          position: Vector2(index * cellWidth - 16, 650),
          size: Vector2(32, 374),
          style: PlatformSurfaceStyle.damage,
        ),
    ]);
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 1080, boundary: true),
      _surface(worldSize.x - 24, 0, 24, 1080, boundary: true),
      // ROOM 1-1: broken conduit workshop.
      _surface(0, 1024, 420, 56),
      _surface(510, 1024, 450, 56),
      _surface(110, 900, 220, 22),
      _surface(570, 820, 250, 22),
      MovingPlatformComponent(
        start: Vector2(390, 920),
        end: Vector2(390, 760),
        size: Vector2(110, 22),
        periodSeconds: 3.2,
      ),
      // ROOM 1-2: assembly line with alternating heights.
      _surface(960, 1024, 360, 56),
      _surface(1420, 1024, 500, 56),
      _surface(1060, 884, 210, 22),
      ConveyorPlatformComponent(
        position: Vector2(1420, 900),
        size: Vector2(260, 24),
        direction: -1,
      ),
      _surface(1690, 790, 170, 22),
      // ROOM 1-3: unstable overflow test chamber.
      _surface(1920, 1024, 380, 56),
      _surface(2410, 1024, 470, 56),
      _surface(2010, 900, 210, 22),
      MovingPlatformComponent(
        start: Vector2(2310, 910),
        end: Vector2(2450, 760),
        size: Vector2(120, 22),
        periodSeconds: 3.8,
      ),
      ConveyorPlatformComponent(
        position: Vector2(2590, 850),
        size: Vector2(220, 24),
        direction: 1,
      ),
      // Boss cell: broad floor and two recovery platforms.
      _surface(2880, 1024, 960, 56),
      _surface(3070, 850, 180, 22),
      _surface(3530, 850, 180, 22),
      ..._encounterGates,
    ]);
  }

  Future<void> _addHazardsAndTraversal() async {
    await addAll(<Component>[
      DamagePitComponent(position: Vector2(420, 1024), size: Vector2(90, 56)),
      DamagePitComponent(position: Vector2(1320, 1024), size: Vector2(100, 56)),
      DamagePitComponent(position: Vector2(2300, 1024), size: Vector2(110, 56)),
      RoomHazardComponent(
        position: Vector2(620, 808),
        size: Vector2(90, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.damage-lab.room1-1.conduit-spikes',
      ),
      PulsingLaserComponent(
        position: Vector2(1560, 660),
        size: Vector2(14, 364),
        sourceId: 'hazard.damage-lab.room1-2.assembly-laser',
      ),
      RoomHazardComponent(
        position: Vector2(2635, 838),
        size: Vector2(90, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.damage-lab.room1-3.overflow-spikes',
      ),
      PulsingLaserComponent(
        position: Vector2(2790, 770),
        size: Vector2(14, 254),
        sourceId: 'hazard.damage-lab.room1-3.exit-laser',
        phaseOffset: 1.1,
      ),
      JumpPadComponent(position: Vector2(535, 1012)),
      JumpPadComponent(position: Vector2(1450, 1012)),
      JumpPadComponent(position: Vector2(2440, 1012)),
      CheckpointBeaconComponent(
        position: Vector2(1015, 1024),
        index: 1,
        onActivated: _activateCheckpoint,
      ),
      CheckpointBeaconComponent(
        position: Vector2(1975, 1024),
        index: 2,
        onActivated: _activateCheckpoint,
      ),
      CheckpointBeaconComponent(
        position: Vector2(2935, 1024),
        index: 3,
        onActivated: _activateCheckpoint,
      ),
    ]);
  }

  Future<void> _addEncounters() async {
    final specs = <(int, PlatformerEnemyArchetype, double, double)>[
      (0, PlatformerEnemyArchetype.patchMite, 300, 972),
      (0, PlatformerEnemyArchetype.checksumHopper, 720, 782),
      (1, PlatformerEnemyArchetype.pulseTurret, 1160, 844),
      (1, PlatformerEnemyArchetype.checksumHopper, 1760, 752),
      (2, PlatformerEnemyArchetype.patchMite, 2130, 862),
      (2, PlatformerEnemyArchetype.repairLeech, 2680, 812),
    ];
    for (final spec in specs) {
      if (progress.clearedEncounterIds.contains(spec.$1)) continue;
      late final PlatformerEnemyComponent enemy;
      enemy = PlatformerEnemyComponent(
        archetype: spec.$2,
        position: Vector2(spec.$3, spec.$4),
        onDefeated: _onEnemyDefeated,
        startsDormant: true,
      );
      _enemyEncounterIds[enemy] = spec.$1;
      await add(enemy);
    }
  }

  Future<void> _addOptionalQuest() async {
    for (final spec in <(int, double, double)>[
      (0, 855, 1018),
      (1, 1810, 1018),
      (2, 2750, 1018),
    ]) {
      if (progress.collectedRecordIds.contains(spec.$1)) continue;
      final terminal = QaRecordTerminalComponent(
        position: Vector2(spec.$2, spec.$3),
        recordId: spec.$1,
        onCollected: _onRecordCollected,
      );
      _recordTerminals.add(terminal);
      await add(terminal);
    }
    if (progress.questComplete && !progress.questRewardClaimed) {
      await _spawnQuestReward();
    }
  }

  Future<void> _addBossRoom() async {
    if (!progress.bossDefeated) {
      final boss = OverflowWardenBossComponent(
        position: Vector2(3400, 968),
        onDefeated: _onBossDefeated,
      );
      _boss = boss;
      await add(boss);
    } else {
      if (!progress.bossRewardClaimed) await _spawnBossReward();
      await _spawnExitTerminal();
    }
  }

  PlatformSurfaceComponent _surface(
    double x,
    double y,
    double width,
    double height, {
    bool boundary = false,
  }) => PlatformSurfaceComponent(
    position: Vector2(x, y),
    size: Vector2(width, height),
    isBoundary: boundary,
  );

  void _synchronizeGateState() {
    for (var index = 0; index < _encounterGates.length; index += 1) {
      final gate = _encounterGates[index];
      if (index < 2 && progress.clearedEncounterIds.contains(index)) {
        gate.unlock();
      } else if (index == 2 && progress.allEncountersCleared) {
        gate.unlock();
      } else {
        gate.lock();
      }
    }
  }

  void _activateCheckpoint(int index, Vector2 respawnPoint) {
    _respawnPoint = respawnPoint;
  }

  void _activateEncounter(int encounterId) {
    if (progress.clearedEncounterIds.contains(encounterId)) return;
    for (final entry in _enemyEncounterIds.entries) {
      if (entry.value == encounterId) entry.key.activateEncounter();
    }
  }

  void _onEnemyDefeated(PlatformerEnemyComponent enemy) {
    final encounterId = _enemyEncounterIds[enemy];
    if (encounterId == null || !_defeatedEnemies.add(enemy)) return;
    _defeatedCount += 1;
    game.runMetrics.recordOverflow();
    final encounterEnemies = _enemyEncounterIds.entries
        .where((entry) => entry.value == encounterId)
        .map((entry) => entry.key);
    if (encounterEnemies.every(_defeatedEnemies.contains)) {
      progress.clearedEncounterIds.add(encounterId);
      _encounterGates[encounterId].unlock();
      if (game.runItems.contains(RunItemId.conduitHeart)) {
        game.world.player.restoreIntegrity(1);
      }
    }
    game.publishUiSnapshot(force: true);
  }

  void _onRecordCollected(int recordId) {
    progress.collectedRecordIds.add(recordId);
    _recordTerminals.removeWhere((terminal) => terminal.recordId == recordId);
    game.world.player.absorbDataShard(amount: 2);
    if (progress.questComplete && !progress.questRewardClaimed) {
      unawaited(_spawnQuestReward());
    }
    game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnQuestReward() async {
    if (_questReward != null || progress.questRewardClaimed) return;
    final reward = ItemPedestalComponent(
      position: Vector2(2515, 1018),
      item: RunItemId.conduitHeart,
      rewardTier: ItemRewardTier.quest,
      onCollected: (_) {
        progress.questRewardClaimed = true;
        _questReward = null;
      },
    );
    _questReward = reward;
    await add(reward);
  }

  void _startBossIntro() {
    final boss = _boss;
    if (_bossEncounterStarted ||
        boss == null ||
        !progress.allEncountersCleared) {
      return;
    }
    _bossEncounterStarted = true;
    _bossIntroRemaining = 2.8;
    _encounterGates[2].lock();
    boss.beginIntro();
    game.setCinematicInputLocked(true);
    final banner = TextComponent(
      text: game.localization.text('boss.overflowWarden.intro'),
      position: Vector2(3360, 650),
      anchor: Anchor.center,
      priority: 40,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'PatchWorldCJK',
          color: Color(0xFFFFD35A),
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.4,
        ),
      ),
    );
    _bossBanner = banner;
    add(banner);
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  void _onBossDefeated() {
    progress.bossDefeated = true;
    _encounterGates[2].unlock();
    _boss = null;
    game.runMetrics.recordOverflow();
    unawaited(_spawnBossReward());
    unawaited(_spawnExitTerminal());
    game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnBossReward() async {
    if (_bossReward != null || progress.bossRewardClaimed) return;
    final reward = ItemPedestalComponent(
      position: Vector2(3450, 1018),
      item: RunItemId.overflowCapacitor,
      rewardTier: ItemRewardTier.boss,
      onCollected: (_) {
        progress.bossRewardClaimed = true;
        _bossReward = null;
      },
    );
    _bossReward = reward;
    await add(reward);
  }

  Future<void> _spawnExitTerminal() async {
    if (_exitTerminal != null) return;
    final terminal = _PatchExitTerminalComponent(position: Vector2(3710, 1018));
    _exitTerminal = terminal;
    await add(terminal);
  }

  bool tryInteract(PlayerComponent player) {
    if (_hubDoor?.tryEnter(player) ?? false) return true;
    for (final terminal in _recordTerminals.toList()) {
      if (terminal.tryCollect(player)) return true;
    }
    if (_questReward?.tryCollect(player) ?? false) return true;
    if (_bossReward?.tryCollect(player) ?? false) return true;
    final exit = _exitTerminal;
    if (exit == null || !exit.isNear(player)) return false;
    if (!progress.bossRewardClaimed || _patchSelectionOpened) return true;
    _patchSelectionOpened = true;
    game.openRoomOnePatchSelection();
    return true;
  }

  @override
  void update(double dt) {
    if (!game.world.isReady) {
      super.update(dt);
      return;
    }
    _currentCell = (game.world.player.position.x / cellWidth).floor().clamp(
      0,
      3,
    );
    if (_currentCell < encounterCount) {
      _activateEncounter(_currentCell);
    } else if (progress.allEncountersCleared && !progress.bossDefeated) {
      _startBossIntro();
    }
    if (_bossIntroRemaining > 0) {
      _bossIntroRemaining = math.max(
        0,
        _bossIntroRemaining - game.clock.simulationDt,
      );
      if (_bossIntroRemaining <= 0) {
        _bossBanner?.removeFromParent();
        _bossBanner = null;
        game.setCinematicInputLocked(false);
        _boss?.activate();
      }
    }
    super.update(dt);
  }

  @override
  void onRemove() {
    game.setCinematicInputLocked(false);
    super.onRemove();
  }
}

final class _PatchExitTerminalComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  _PatchExitTerminalComponent({required super.position})
    : super(size: Vector2(64, 84), anchor: Anchor.bottomCenter, priority: 16);

  double _clock = 0;

  bool isNear(PlayerComponent player) =>
      player.position.distanceTo(position) <= 82;

  @override
  void update(double dt) {
    _clock += game.clock.simulationDt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final glow = 120 + (math.sin(_clock * 4).abs() * 100).round();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, 48, 76),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFF202B50),
    );
    canvas.drawRect(
      const Rect.fromLTWH(16, 18, 32, 42),
      Paint()..color = Color.fromARGB(glow, 255, 211, 90),
    );
    super.render(canvas);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: '${game.localization.text('interaction.applyPatch')}  [L]',
        position: Vector2(size.x / 2, 0),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFFFFE39A),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
