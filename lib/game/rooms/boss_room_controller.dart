import 'dart:async';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';
import 'package:patch_world/game/components/environment/legacy_glitch_terminal.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rules/anomalies/damage_sign_inverted_rule.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/phase_leak_controller.dart';

final class BossRoomController extends Component
    with HasGameReference<PatchWorldGame> {
  late final OptimizerBossComponent boss;
  late final LegacyGlitchTerminal terminal;
  final PhaseLeakController _phaseLeak = PhaseLeakController();
  final List<PhaseWallComponent> _phaseWalls = <PhaseWallComponent>[];
  double _legacyRemaining = 0;
  double _legacyCooldown = 0;
  bool _legacyActive = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    terminal = LegacyGlitchTerminal(
      position: Vector2(480, 90),
      onActivated: _activateLegacyGlitch,
    );
    boss = OptimizerBossComponent(
      position: Vector2(480, 245),
      onPerfectStateEntered: terminal.enable,
      onDefeated: game.showEnding,
    );
    await addAll(<Component>[terminal, boss]);
    if (game.runState.hasPatch(RuleIds.phaseLeak)) {
      final left = PhaseWallComponent(
        position: Vector2(280, 180),
        size: Vector2(36, 180),
      );
      final right = PhaseWallComponent(
        position: Vector2(644, 180),
        size: Vector2(36, 180),
      );
      _phaseWalls.addAll(<PhaseWallComponent>[left, right]);
      await addAll(_phaseWalls);
    }
  }

  @override
  void update(double dt) {
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
}
