import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/patch_exit_terminal_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/qa_record_terminal_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/items/item_pedestal_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

final class ChapterEnemySpawn {
  const ChapterEnemySpawn(this.encounterId, this.archetype, this.x, this.y);

  final int encounterId;
  final PlatformerEnemyArchetype archetype;
  final double x;
  final double y;
}

abstract class FourCellChapterController extends Component
    with HasGameReference<PatchWorldGame>
    implements PlatformerRoomGeometry, PlatformerRoomCameraTarget {
  FourCellChapterController({required this.progress});

  static const double cellWidth = 960;
  static const int encounterCount = 3;

  final CampaignFloorState progress;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  final Map<PlatformerEnemyComponent, int> _enemyEncounterIds =
      <PlatformerEnemyComponent, int>{};
  final Set<PlatformerEnemyComponent> _defeatedEnemies =
      <PlatformerEnemyComponent>{};
  final List<BossSealGateComponent> _encounterGates = <BossSealGateComponent>[];
  final List<QaRecordTerminalComponent> _recordTerminals =
      <QaRecordTerminalComponent>[];

  CampaignChapterBossComponent? _boss;
  ItemPedestalComponent? _questReward;
  ItemPedestalComponent? _bossReward;
  PatchExitTerminalComponent? _exitTerminal;
  TextComponent? _bossBanner;
  Vector2 _respawnPoint = Vector2(70, 988);
  int _currentCell = 0;
  int _defeatedCount = 0;
  double _bossIntroRemaining = 0;
  bool _bossEncounterStarted = false;
  bool _patchSelectionOpened = false;

  PlatformSurfaceStyle get surfaceStyle;
  RoomBackdropStyle get backdropStyle;
  CampaignChapterBossKind get bossKind;
  RunItemId get questRewardItem;
  RunItemId get bossRewardItem;
  String get recordLocalizationKey;
  String get bossIntroLocalizationKey;
  Color get chapterAccentColor;
  List<ChapterEnemySpawn> get enemySpawns;

  List<PlatformSurfaceComponent> buildChapterSurfaces();
  List<Component> buildChapterFeatures();
  void openPatchSelection();

  List<Vector2> get recordPositions => <Vector2>[
    Vector2(855, 1018),
    Vector2(1810, 1018),
    Vector2(2750, 1018),
  ];
  Vector2 get questRewardPosition => Vector2(2515, 1018);
  Vector2 get bossPosition => Vector2(3400, 968);
  Vector2 get bossRewardPosition => Vector2(3450, 1018);
  Vector2 get exitTerminalPosition => Vector2(3710, 1018);

  @override
  Vector2 get playerSpawn => Vector2(progress.resumeCell * cellWidth + 70, 988);

  @override
  final Vector2 worldSize = Vector2(cellWidth * 4, 1080);

  @override
  double get killPlaneY => 1160;

  int get defeatedCount => _defeatedCount;
  int get clearedEncounterCount => progress.clearedEncounterCount;
  int get recordCount => progress.collectedRecordCount;
  int get currentCellNumber => (_currentCell + 1).clamp(1, 4);
  bool get isCompleted => progress.bossDefeated;
  bool get isBossIntroActive => _bossIntroRemaining > 0;
  int? get bossHealth => _bossEncounterStarted ? _boss?.health : null;
  int? get bossMaxHealth => _bossEncounterStarted ? _boss?.maxHealth : null;
  String? get bossPhaseKey => _bossEncounterStarted ? _boss?.phaseId : null;
  CampaignChapterBossComponent? get boss => _boss;
  List<BossSealGateComponent> get encounterGates =>
      List<BossSealGateComponent>.unmodifiable(_encounterGates);

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
    return Vector2(
      targetCell * cellWidth + cellWidth / 2,
      isBossIntroActive ? 790 : playerPosition.y.clamp(270, 810).toDouble(),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _respawnPoint = playerSpawn;
    _currentCell = progress.resumeCell;
    await add(RoomBackdropComponent(backdropStyle, worldSize: worldSize));
    _encounterGates.addAll(<BossSealGateComponent>[
      for (var index = 1; index <= 3; index += 1)
        BossSealGateComponent(
          position: Vector2(index * cellWidth - 16, 650),
          size: Vector2(32, 374),
          style: surfaceStyle,
        ),
    ]);
    _surfaces.addAll(buildChapterSurfaces());
    _surfaces.addAll(_encounterGates);
    await addAll(_surfaces);
    await addAll(buildChapterFeatures());
    await _addEncounters();
    await _addRecords();
    await _addBossRoom();
    _synchronizeGateState();
  }

  PlatformSurfaceComponent surface(
    double x,
    double y,
    double width,
    double height, {
    bool boundary = false,
  }) => PlatformSurfaceComponent(
    position: Vector2(x, y),
    size: Vector2(width, height),
    isBoundary: boundary,
    style: surfaceStyle,
  );

  void onCheckpointActivated(int index, Vector2 respawnPoint) {
    _respawnPoint = respawnPoint;
  }

  Future<void> _addEncounters() async {
    for (final spec in enemySpawns) {
      if (progress.clearedEncounterIds.contains(spec.encounterId)) continue;
      late final PlatformerEnemyComponent enemy;
      enemy = PlatformerEnemyComponent(
        archetype: spec.archetype,
        position: Vector2(spec.x, spec.y),
        onDefeated: _onEnemyDefeated,
        startsDormant: true,
      );
      _enemyEncounterIds[enemy] = spec.encounterId;
      await add(enemy);
    }
  }

  Future<void> _addRecords() async {
    final positions = recordPositions;
    for (var index = 0; index < positions.length; index += 1) {
      if (progress.collectedRecordIds.contains(index)) continue;
      final terminal = QaRecordTerminalComponent(
        position: positions[index],
        recordId: index,
        labelLocalizationKey: recordLocalizationKey,
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
      final nextBoss = CampaignChapterBossComponent(
        position: bossPosition,
        kind: bossKind,
        onDefeated: _onBossDefeated,
      );
      _boss = nextBoss;
      await add(nextBoss);
    } else {
      if (!progress.bossRewardClaimed) await _spawnBossReward();
      await _spawnExitTerminal();
    }
  }

  void _synchronizeGateState() {
    for (var index = 0; index < _encounterGates.length; index += 1) {
      if (progress.clearedEncounterIds.contains(index)) {
        _encounterGates[index].unlock();
      } else {
        _encounterGates[index].lock();
      }
    }
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
      position: questRewardPosition,
      item: questRewardItem,
      onCollected: (_) {
        progress.questRewardClaimed = true;
        _questReward = null;
      },
    );
    _questReward = reward;
    await add(reward);
  }

  void _startBossIntro() {
    final activeBoss = _boss;
    if (_bossEncounterStarted ||
        activeBoss == null ||
        !progress.allEncountersCleared) {
      return;
    }
    _bossEncounterStarted = true;
    _bossIntroRemaining = 2.8;
    _encounterGates[2].lock();
    activeBoss.beginIntro();
    game.setCinematicInputLocked(true);
    final banner = TextComponent(
      text: game.localization.text(bossIntroLocalizationKey),
      position: Vector2(3360, 650),
      anchor: Anchor.center,
      priority: 40,
      textRenderer: TextPaint(
        style: TextStyle(
          color: chapterAccentColor,
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
      position: bossRewardPosition,
      item: bossRewardItem,
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
    final terminal = PatchExitTerminalComponent(
      position: exitTerminalPosition,
      accentColor: chapterAccentColor,
    );
    _exitTerminal = terminal;
    await add(terminal);
  }

  bool tryInteract(PlayerComponent player) {
    for (final terminal in _recordTerminals.toList()) {
      if (terminal.tryCollect(player)) return true;
    }
    if (_questReward?.tryCollect(player) ?? false) return true;
    if (_bossReward?.tryCollect(player) ?? false) return true;
    final exit = _exitTerminal;
    if (exit == null || !exit.isNear(player)) return false;
    if (!progress.bossRewardClaimed || _patchSelectionOpened) return true;
    _patchSelectionOpened = true;
    openPatchSelection();
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
      // Temporal Hall intentionally freezes simulation without input. Boss
      // cinematics use real time so the input lock cannot deadlock the intro.
      _bossIntroRemaining = math.max(
        0,
        _bossIntroRemaining - game.clock.realDt,
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
