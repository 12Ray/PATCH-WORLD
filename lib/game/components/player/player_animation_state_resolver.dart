import 'package:patch_world/game/combat/player_weapon.dart';

const double playerRunAnimationEnterThreshold = 10;
const double playerRunAnimationExitThreshold = 3;
const double playerAirAnimationThreshold = 60;

PlayerAnimationState resolvePlayerAnimationState({
  required bool usesPlatformerMovement,
  required bool grounded,
  required double horizontalVelocity,
  required double verticalVelocity,
  required bool isMoving,
  PlayerAnimationState? currentState,
}) {
  if (!usesPlatformerMovement) {
    return isMoving ? PlayerAnimationState.run : PlayerAnimationState.idle;
  }
  if (grounded) {
    final threshold = currentState == PlayerAnimationState.run
        ? playerRunAnimationExitThreshold
        : playerRunAnimationEnterThreshold;
    return horizontalVelocity.abs() > threshold
        ? PlayerAnimationState.run
        : PlayerAnimationState.idle;
  }
  if (verticalVelocity < -playerAirAnimationThreshold) {
    return PlayerAnimationState.jumpRise;
  }
  if (verticalVelocity > playerAirAnimationThreshold) {
    return PlayerAnimationState.fall;
  }
  return PlayerAnimationState.apex;
}
