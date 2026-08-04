import 'package:flame/components.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/motion_tax_controller.dart';
import 'package:patch_world/game/systems/retaliation_echo_controller.dart';

typedef SpawnEcho = void Function(Vector2 position);
typedef DamagePlayer = void Function(int amount, String causeId);

final class PatchEffectsSystem {
  PatchEffectsSystem({
    required this.runState,
    required this.spawnEcho,
    required this.damagePlayer,
  });

  final RunState runState;
  final SpawnEcho spawnEcho;
  final DamagePlayer damagePlayer;
  final MotionTaxController motionTax = MotionTaxController();
  final RetaliationEchoController retaliationEcho = RetaliationEchoController();

  bool get hasMotionTax => runState.hasPatch(RuleIds.motionTax);
  bool get hasRetaliationEcho => runState.hasPatch(RuleIds.retaliationEcho);
  double? get normalizedHeat => hasMotionTax ? motionTax.normalizedHeat : null;
  int? get echoPulseCount =>
      hasRetaliationEcho ? retaliationEcho.pulseCount : null;

  void update({required double playerStatusDt, required bool isPlayerMoving}) {
    if (!hasMotionTax) {
      return;
    }
    final result = motionTax.update(
      dt: playerStatusDt,
      isMoving: isPlayerMoving,
    );
    if (result.didOverheat) {
      damagePlayer(1, RuleIds.motionTax);
    }
  }

  void onPatchPulseEmitted(Vector2 worldPosition) {
    if (hasRetaliationEcho && retaliationEcho.recordPulse()) {
      spawnEcho(worldPosition.clone());
    }
  }

  void resetForRoomRestart() {
    motionTax.reset();
    retaliationEcho.reset();
  }

  void resetTransientForRoomTransition() => retaliationEcho.reset();
}
