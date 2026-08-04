import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/frame_burst_controller.dart';

final class EnemyTempoSystem {
  EnemyTempoSystem({required this.runState});
  final RunState runState;
  final FrameBurstController frameBurst = FrameBurstController();

  bool get hasHostileTurbo => runState.hasPatch(RuleIds.hostileTurbo);
  bool get hasFrameBurst => runState.hasPatch(RuleIds.frameBurst);
  FrameBurstSnapshot? get frameBurstSnapshot =>
      hasFrameBurst ? frameBurst.snapshot : null;
  bool didFrameBurstEnd = false;

  double get speedMultiplier {
    var multiplier = 1.0;
    if (hasHostileTurbo) multiplier *= 1.20;
    if (hasFrameBurst) multiplier *= frameBurst.speedMultiplier;
    return multiplier;
  }

  void update(double realDt) {
    didFrameBurstEnd = false;
    if (hasFrameBurst) {
      final previousPhase = frameBurst.phase;
      frameBurst.update(realDt);
      didFrameBurstEnd =
          previousPhase == FrameBurstPhase.active &&
          frameBurst.phase == FrameBurstPhase.normal;
    } else {
      frameBurst.reset();
    }
  }

  void resetForRoomRestart() {
    frameBurst.reset();
    didFrameBurstEnd = false;
  }
}
