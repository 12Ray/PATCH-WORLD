import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/story_map_art_contract.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';
import 'package:patch_world/game/components/environment/legacy_glitch_terminal.dart';
import 'package:patch_world/game/components/environment/optimizer_arena_stage_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/systems/phase_leak_controller.dart';
import 'package:patch_world/services/audio_service.dart';

final class BossRoomController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomSurfaceMotion,
        PlatformerRoomCameraTarget,
        PlatformerRoomCameraZoom,
        PlatformerRoomPlayerCameraSafety,
        CampaignNodeRoom {
  late final OptimizerBossComponent boss;
  late final LegacyGlitchTerminal terminal;
  late final OptimizerArenaStageComponent arenaStage;
  final PhaseLeakController _phaseLeak = PhaseLeakController();
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  final List<PhaseWallComponent> _phaseWalls = <PhaseWallComponent>[];
  final List<OptimizerPhasePlatformComponent> _phasePlatforms =
      <OptimizerPhasePlatformComponent>[];
  final List<OptimizerPhaseBreakablePlatformComponent> _breakablePlatforms =
      <OptimizerPhaseBreakablePlatformComponent>[];
  final List<OptimizerPhaseLaserComponent> _phaseLasers =
      <OptimizerPhaseLaserComponent>[];
  bool _bossIntroStarted = false;
  double _bossIntroRemaining = 0;
  BossNameCardComponent? _bossNameCard;
  bool _playedBossIntroAudio = false;
  bool _playedBossVictoryAudio = false;
  final Set<int> _playedBossAudioPhases = <int>{};

  bool get isBossIntroActive => _bossIntroRemaining > 0;
  List<OptimizerPhasePlatformComponent> get phasePlatforms =>
      List<OptimizerPhasePlatformComponent>.unmodifiable(_phasePlatforms);
  List<OptimizerPhaseBreakablePlatformComponent> get breakablePlatforms =>
      List<OptimizerPhaseBreakablePlatformComponent>.unmodifiable(
        _breakablePlatforms,
      );
  List<OptimizerPhaseLaserComponent> get phaseLasers =>
      List<OptimizerPhaseLaserComponent>.unmodifiable(_phaseLasers);
  List<PhaseWallComponent> get phaseWalls =>
      List<PhaseWallComponent>.unmodifiable(_phaseWalls);

  @override
  CampaignNodeId get campaignNodeId => CampaignNodeId.optimizerCore;

  @override
  final Vector2 playerSpawn = Vector2(180, 988);

  @override
  final Vector2 worldSize = Vector2(1920, 1080);

  @override
  double get killPlaneY => 1160;

  @override
  Iterable<Rect> get solidBounds sync* {
    yield* _surfaces
        .where((surface) => surface.isSolid)
        .map((surface) => surface.bounds);
    yield* _phaseWalls
        .where((wall) => wall.isSolid)
        .map(
          (wall) => Rect.fromLTWH(
            wall.position.x,
            wall.position.y,
            wall.size.x,
            wall.size.y,
          ),
        );
  }

  @override
  Vector2? surfaceDisplacementFor(Rect playerBounds) {
    for (final surface in _surfaces) {
      final displacement = surface.supportDisplacementFor(playerBounds);
      if (displacement != null) return displacement;
    }
    return null;
  }

  @override
  Vector2? surfaceVelocityFor(Rect playerBounds) {
    for (final surface in _surfaces) {
      final velocity = surface.supportVelocityFor(playerBounds);
      if (velocity != null) return velocity;
    }
    return null;
  }

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) {
    if (playerPosition.x > 1320) return Vector2(1640, 848);
    if (playerPosition.x > 620) return Vector2(960, 468);
    return playerSpawn.clone();
  }

  @override
  Vector2 cameraTargetFor(Vector2 playerPosition) {
    if (isBossIntroActive) {
      // Establish the arena from the entrance instead of cutting away from
      // the player to the boss. Combat can widen after control is returned.
      return Vector2(playerPosition.x + 220, playerPosition.y - 170);
    }
    if (!boss.isEncounterActive && !boss.isOutroActive) {
      return playerPosition.clone();
    }
    if (terminal.isEnabled) {
      // PERFECT is an interaction phase, so the required terminal becomes
      // the camera focus without losing the player at the edge of the view.
      return Vector2(
        playerPosition.x * .55 + terminal.position.x * .45,
        playerPosition.y * .55 + terminal.position.y * .45 - 60,
      );
    }
    return (playerPosition + boss.position) / 2;
  }

  @override
  double cameraZoomFor(Vector2 playerPosition) {
    if (isBossIntroActive) return .9;
    if (!boss.isEncounterActive && !boss.isOutroActive) return 1;
    if (terminal.isEnabled) return .92;
    final horizontalSpan = (playerPosition.x - boss.position.x).abs() + 250;
    final verticalSpan = (playerPosition.y - boss.position.y).abs() + 150;
    return math
        .min(960 / horizontalSpan, 540 / verticalSpan)
        .clamp(.9, 1.06)
        .toDouble();
  }

  @override
  bool get keepsPlayerInsideHorizontalSafeArea => true;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final mapArtSpec = StoryMapArtCatalog.specFor(campaignNodeId);
    await add(
      StoryRoomLayersComponent(
        theme: mapArtSpec.theme,
        motif: mapArtSpec.motif,
        worldSize: worldSize,
      ),
    );
    arenaStage = OptimizerArenaStageComponent(worldSize: worldSize);
    await add(arenaStage);
    _phasePlatforms.addAll(<OptimizerPhasePlatformComponent>[
      OptimizerPhasePlatformComponent(
        start: Vector2(620, 900),
        end: Vector2(620, 660),
        size: Vector2(120, 22),
        periodSeconds: 3.4,
      ),
      OptimizerPhasePlatformComponent(
        start: Vector2(1180, 660),
        end: Vector2(1180, 900),
        size: Vector2(120, 22),
        periodSeconds: 3.4,
      ),
    ]);
    _breakablePlatforms.addAll(<OptimizerPhaseBreakablePlatformComponent>[
      OptimizerPhaseBreakablePlatformComponent(
        position: Vector2(280, 650),
        size: Vector2(150, 22),
      ),
      OptimizerPhaseBreakablePlatformComponent(
        position: Vector2(1490, 650),
        size: Vector2(150, 22),
      ),
    ]);
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 1080, boundary: true),
      _surface(1896, 0, 24, 1080, boundary: true),
      _surface(0, 1024, 500, 56),
      _surface(610, 1024, 700, 56),
      _surface(1420, 1024, 500, 56),
      // The permanent route is a mirrored 80 px staircase. 80 px is the
      // campaign's conservative single-jump rise, so the sword never needs
      // its dash (or a phase platform) to cross the Core or reach melee
      // height. The animated platforms remain tactical shortcuts only.
      _surface(100, 944, 280, 24),
      _surface(400, 864, 220, 24),
      _surface(690, 784, 200, 24),
      _surface(760, 704, 160, 24),
      _surface(800, 624, 160, 24),
      _surface(850, 544, 220, 28),
      _surface(960, 624, 160, 24),
      _surface(1000, 704, 160, 24),
      _surface(1130, 784, 200, 24),
      _surface(1380, 864, 220, 24),
      _surface(1580, 944, 280, 24),
      // These visible firewall blocks replace the old invisible walls. They
      // still frame each data pit, but a normal jump clears them.
      _surface(560, 944, 42, 80),
      _surface(1318, 944, 42, 80),
      ..._phasePlatforms,
      ..._breakablePlatforms,
    ]);
    await addAll(_surfaces);
    _phaseLasers.addAll(<OptimizerPhaseLaserComponent>[
      OptimizerPhaseLaserComponent(
        position: Vector2(520, 600),
        size: Vector2(14, 220),
        sourceId: 'boss.optimizer.arenaLaser.left',
      ),
      OptimizerPhaseLaserComponent(
        position: Vector2(1386, 600),
        size: Vector2(14, 220),
        sourceId: 'boss.optimizer.arenaLaser.right',
        phaseOffset: .55,
      ),
    ]);
    await addAll(<Component>[
      DamagePitComponent(
        position: Vector2(500, 1024),
        size: Vector2(110, 56),
        style: PlatformSurfaceStyle.optimizer,
      ),
      DamagePitComponent(
        position: Vector2(1310, 1024),
        size: Vector2(110, 56),
        style: PlatformSurfaceStyle.optimizer,
      ),
      RoomHazardComponent(
        position: Vector2(760, 1012),
        size: Vector2(96, 12),
        style: RoomHazardStyle.spikes,
        surfaceStyle: PlatformSurfaceStyle.optimizer,
        sourceId: 'hazard.optimizer.perfect-teeth-left',
      ),
      RoomHazardComponent(
        position: Vector2(1064, 1012),
        size: Vector2(96, 12),
        style: RoomHazardStyle.spikes,
        surfaceStyle: PlatformSurfaceStyle.optimizer,
        sourceId: 'hazard.optimizer.perfect-teeth-right',
      ),
      ..._phaseLasers,
      JumpPadComponent(
        position: Vector2(430, 1012),
        style: PlatformSurfaceStyle.optimizer,
      ),
      JumpPadComponent(
        position: Vector2(1460, 1012),
        style: PlatformSurfaceStyle.optimizer,
      ),
    ]);

    terminal = LegacyGlitchTerminal(
      // PERFECT is an interaction phase, so the required terminal sits on
      // the permanent center floor. It must never depend on the moving or
      // upper-platform route while the boss is waiting for this input.
      position: Vector2(960, 980),
      onActivated: _completeTerminalPhase,
    );
    boss = OptimizerBossComponent(
      position: Vector2(960, 330),
      onPerfectStateEntered: terminal.enable,
      onPhaseChanged: _handleBossPhaseChanged,
      onCoreExposed: _handleCoreExposed,
      onDefeated: _handleBossDefeated,
      startsActive: false,
    );
    await addAll(<Component>[terminal, boss]);
    _applyArenaPhase(OptimizerPhase.analyze);

    if (game.runState.hasPatch(RuleIds.phaseLeak)) {
      _phaseWalls.addAll(<PhaseWallComponent>[
        PhaseWallComponent(position: Vector2(760, 520), size: Vector2(28, 504)),
        PhaseWallComponent(
          position: Vector2(1132, 520),
          size: Vector2(28, 504),
        ),
      ]);
      await addAll(_phaseWalls);
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
    style: PlatformSurfaceStyle.optimizer,
    renderArtwork: !boundary,
  );

  @override
  void update(double dt) {
    if (game.world.isReady && !_bossIntroStarted) _startBossIntro();
    if (_bossIntroRemaining > 0) {
      _bossIntroRemaining = math.max(
        0,
        _bossIntroRemaining - game.clock.realDt,
      );
      if (_bossIntroRemaining <= 0) {
        _bossNameCard?.removeFromParent();
        _bossNameCard = null;
        boss.activateEncounter();
        _playBossPhaseAudioOnce(1);
        game.setCinematicInputLocked(false);
      }
    }
    final simulationDt = game.clock.simulationDt;
    if (_phaseWalls.isNotEmpty) {
      _phaseLeak.update(simulationDt);
      final phaseAllowsSolid = _phaseLeak.phase != PhaseLeakPhase.open;
      final playerBounds = game.world.player.damageHitboxBounds;
      for (final wall in _phaseWalls) {
        final safelySolid =
            phaseAllowsSolid && wall.canSolidifyAround(playerBounds);
        unawaited(wall.setSolid(safelySolid));
      }
    }
    super.update(dt);
  }

  void _startBossIntro() {
    if (_bossIntroStarted) return;
    _bossIntroStarted = true;
    _bossIntroRemaining = 2.8;
    game.setCinematicInputLocked(true);
    final card = BossNameCardComponent(
      center: Vector2(520, 560),
      title: game.localization.text('boss.optimizer.name'),
      subtitle: game.localization.text('boss.optimizer.intro'),
      accentColor: const Color(0xFFFFD35A),
    );
    _bossNameCard = card;
    add(card);
    game.triggerImpactFeedback();
    if (!_playedBossIntroAudio) {
      _playedBossIntroAudio = true;
      unawaited(
        game.audio.playStoryBossIntro(StoryBossAudioIdentity.optimizer),
      );
    }
  }

  void _handleBossPhaseChanged(OptimizerPhase phase) {
    _applyArenaPhase(phase);
    switch (phase) {
      case OptimizerPhase.analyze:
        _playBossPhaseAudioOnce(1);
      case OptimizerPhase.predict:
        _playBossPhaseAudioOnce(2);
      case OptimizerPhase.perfect:
        _playBossPhaseAudioOnce(3);
      case OptimizerPhase.overflow || OptimizerPhase.defeated:
        break;
    }
  }

  void _applyArenaPhase(OptimizerPhase phase) {
    arenaStage.setPhase(phase);
    for (final platform in _phasePlatforms) {
      platform.setPhase(phase);
    }
    for (final platform in _breakablePlatforms) {
      platform.setPhase(phase);
    }
    for (final laser in _phaseLasers) {
      laser.setPhase(phase);
    }
  }

  void _playBossPhaseAudioOnce(int phase) {
    if (!_playedBossAudioPhases.add(phase)) return;
    unawaited(
      game.audio.playStoryBossPhase(
        StoryBossAudioIdentity.optimizer,
        phase: phase,
      ),
    );
  }

  void _handleCoreExposed() {
    arenaStage.revealCore();
    game.triggerImpactFeedback(intensity: 1.6);
  }

  void _handleBossDefeated() {
    if (!_playedBossVictoryAudio) {
      _playedBossVictoryAudio = true;
      unawaited(
        game.audio.playStoryBossVictory(StoryBossAudioIdentity.optimizer),
      );
    }
    game.showEnding();
  }

  bool tryInteract(PlayerComponent player) =>
      terminal.tryActivate(player.position);

  void _completeTerminalPhase() {
    if (boss.phase != OptimizerPhase.perfect) return;
    // The terminal is the entire PERFECT-phase objective. Activating it
    // completes the stability override immediately; no timed return trip or
    // follow-up attacks are required.
    boss.receiveHealing(4);
  }

  @override
  void onRemove() {
    game.setCinematicInputLocked(false);
    super.onRemove();
  }
}
