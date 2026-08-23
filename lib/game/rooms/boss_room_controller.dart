import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';
import 'package:patch_world/game/components/environment/legacy_glitch_terminal.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rules/anomalies/damage_sign_inverted_rule.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/systems/phase_leak_controller.dart';

final class BossRoomController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        PlatformerRoomCameraZoom,
        CampaignNodeRoom {
  late final OptimizerBossComponent boss;
  late final LegacyGlitchTerminal terminal;
  final PhaseLeakController _phaseLeak = PhaseLeakController();
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  final List<PhaseWallComponent> _phaseWalls = <PhaseWallComponent>[];
  double _legacyRemaining = 0;
  double _legacyCooldown = 0;
  bool _legacyActive = false;
  bool _bossIntroStarted = false;
  double _bossIntroRemaining = 0;
  BossNameCardComponent? _bossNameCard;

  bool get isBossIntroActive => _bossIntroRemaining > 0;

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
  Vector2 respawnPointFor(Vector2 playerPosition) {
    if (playerPosition.x > 1320) return Vector2(1640, 848);
    if (playerPosition.x > 620) return Vector2(960, 468);
    return playerSpawn.clone();
  }

  @override
  Vector2 cameraTargetFor(Vector2 playerPosition) =>
      isBossIntroActive ? boss.position.clone() : playerPosition.clone();

  @override
  double cameraZoomFor(Vector2 playerPosition) => isBossIntroActive ? 1.24 : 1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RoomBackdropComponent(RoomBackdropStyle.optimizer, worldSize: worldSize),
    );
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 1080, boundary: true),
      _surface(1896, 0, 24, 1080, boundary: true),
      _surface(0, 1024, 500, 56),
      _surface(610, 1024, 700, 56),
      _surface(1420, 1024, 500, 56),
      _surface(100, 880, 280, 24),
      _surface(400, 760, 220, 24),
      _surface(690, 640, 200, 24),
      _surface(850, 500, 220, 28),
      _surface(1130, 640, 200, 24),
      _surface(1380, 760, 220, 24),
      _surface(1580, 880, 280, 24),
      _surface(560, 820, 42, 204, boundary: true),
      _surface(1318, 820, 42, 204, boundary: true),
      MovingPlatformComponent(
        start: Vector2(620, 900),
        end: Vector2(620, 660),
        size: Vector2(120, 22),
        periodSeconds: 3.4,
        style: PlatformSurfaceStyle.optimizer,
      ),
      MovingPlatformComponent(
        start: Vector2(1180, 660),
        end: Vector2(1180, 900),
        size: Vector2(120, 22),
        periodSeconds: 3.4,
        style: PlatformSurfaceStyle.optimizer,
      ),
      BreakablePlatformComponent(
        position: Vector2(280, 650),
        size: Vector2(150, 22),
        breakDelay: .65,
        restoreDelay: 2.8,
        style: PlatformSurfaceStyle.optimizer,
      ),
      BreakablePlatformComponent(
        position: Vector2(1490, 650),
        size: Vector2(150, 22),
        breakDelay: .65,
        restoreDelay: 2.8,
        style: PlatformSurfaceStyle.optimizer,
      ),
    ]);
    await addAll(_surfaces);
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
      PulsingLaserComponent(
        position: Vector2(520, 600),
        size: Vector2(14, 220),
        sourceId: 'hazard.optimizer.analysis-column-left',
        style: PlatformSurfaceStyle.optimizer,
      ),
      PulsingLaserComponent(
        position: Vector2(1386, 600),
        size: Vector2(14, 220),
        sourceId: 'hazard.optimizer.analysis-column-right',
        style: PlatformSurfaceStyle.optimizer,
        phaseOffset: 1.2,
      ),
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
      position: Vector2(960, 980),
      onActivated: _activateLegacyGlitch,
    );
    boss = OptimizerBossComponent(
      position: Vector2(960, 330),
      onPerfectStateEntered: terminal.enable,
      onDefeated: game.showEnding,
      startsActive: false,
    );
    await addAll(<Component>[terminal, boss]);

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
        game.setCinematicInputLocked(false);
      }
    }
    final simulationDt = game.clock.simulationDt;
    if (_phaseWalls.isNotEmpty && _phaseLeak.update(simulationDt)) {
      final solid = _phaseLeak.phase != PhaseLeakPhase.open;
      for (final wall in _phaseWalls) {
        unawaited(wall.setSolid(solid));
      }
    }
    if (_legacyActive) {
      _legacyRemaining -= simulationDt;
      if (_legacyRemaining <= 0) _deactivateFailedLegacyGlitch();
    } else if (_legacyCooldown > 0) {
      _legacyCooldown -= simulationDt;
      if (_legacyCooldown <= 0 && boss.phase == OptimizerPhase.perfect) {
        terminal.enable();
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
      center: Vector2(960, 210),
      title: game.localization.text('boss.optimizer.name'),
      subtitle: game.localization.text('boss.optimizer.intro'),
      accentColor: const Color(0xFFFFD35A),
    );
    _bossNameCard = card;
    add(card);
    game.triggerImpactFeedback();
  }

  bool tryInteract(PlayerComponent player) =>
      terminal.tryActivate(player.position);

  void _activateLegacyGlitch() {
    if (_legacyActive || boss.phase != OptimizerPhase.perfect) return;
    _legacyActive = true;
    _legacyRemaining = 6;
    game.ruleEngine.addRule(
      const DamageSignInvertedRule(
        ruleId: RuleIds.legacyDamageInverted,
        rulePriority: 400,
      ),
    );
  }

  void _deactivateFailedLegacyGlitch() {
    _legacyActive = false;
    _legacyRemaining = 0;
    _legacyCooldown = 4;
    game.ruleEngine.removeRule(RuleIds.legacyDamageInverted);
    boss.resetFailedLegacyAttempt();
  }

  void disposeLegacyRule() =>
      game.ruleEngine.removeRule(RuleIds.legacyDamageInverted);

  @override
  void onRemove() {
    game.setCinematicInputLocked(false);
    super.onRemove();
  }
}
