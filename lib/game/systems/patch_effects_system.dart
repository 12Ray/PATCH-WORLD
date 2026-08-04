import 'package:flame/components.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/motion_tax_controller.dart';
import 'package:patch_world/game/systems/retaliation_echo_controller.dart';

typedef SpawnEcho = void Function(Vector2 position, int tier);
typedef SpawnFriendlyBurst =
    void Function(
      Vector2 position,
      int damage,
      double radius, {
      String? excludedEntityId,
    });
typedef DamagePlayer = void Function(int amount, String causeId);

final class PatchEffectsSystem {
  PatchEffectsSystem({
    required this.runState,
    required this.spawnEcho,
    required this.damagePlayer,
    required this.spawnFriendlyBurst,
  });

  final RunState runState;
  final SpawnEcho spawnEcho;
  final DamagePlayer damagePlayer;
  final SpawnFriendlyBurst spawnFriendlyBurst;
  final MotionTaxController motionTax = MotionTaxController();
  final RetaliationEchoController retaliationEcho = RetaliationEchoController();

  bool get hasMotionTax => runState.hasPatch(RuleIds.motionTax);
  bool get hasRetaliationEcho => runState.hasPatch(RuleIds.retaliationEcho);
  double? get normalizedHeat => hasMotionTax ? motionTax.normalizedHeat : null;
  int? get echoPulseCount =>
      hasRetaliationEcho ? retaliationEcho.pulseCount : null;
  bool _motionVentCharged = false;
  double _stationarySeconds = 0;

  bool get motionVentCharged => _motionVentCharged;

  void update({
    required double playerStatusDt,
    required bool isPlayerMoving,
    int motionTaxTier = 0,
    Vector2? playerPosition,
  }) {
    if (!hasMotionTax) {
      _motionVentCharged = false;
      _stationarySeconds = 0;
      return;
    }
    if (motionTaxTier >= 2) {
      if (isPlayerMoving) {
        _stationarySeconds = 0;
      } else if (!_motionVentCharged) {
        _stationarySeconds += playerStatusDt;
        if (_stationarySeconds >= 0.75) _motionVentCharged = true;
      }
    } else {
      _motionVentCharged = false;
      _stationarySeconds = 0;
    }
    final result = motionTax.update(
      dt: playerStatusDt,
      isMoving: isPlayerMoving,
    );
    if (result.didOverheat) {
      if (motionTaxTier >= 3 && playerPosition != null) {
        spawnFriendlyBurst(playerPosition.clone(), 2, 86);
      }
      damagePlayer(1, RuleIds.motionTax);
    }
  }

  bool consumeMotionVentCharge() {
    if (!_motionVentCharged) return false;
    _motionVentCharged = false;
    _stationarySeconds = 0;
    motionTax.cool(25);
    return true;
  }

  void onPatchPulseEmitted(
    Vector2 worldPosition, {
    int retaliationEchoTier = 0,
  }) {
    if (hasRetaliationEcho && retaliationEcho.recordPulse()) {
      spawnEcho(worldPosition.clone(), retaliationEchoTier);
    }
  }

  void resetForRoomRestart() {
    motionTax.reset();
    retaliationEcho.reset();
    _motionVentCharged = false;
    _stationarySeconds = 0;
  }

  void resetTransientForRoomTransition() => retaliationEcho.reset();
}
