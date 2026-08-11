import 'package:patch_world/game/combat/player_weapon.dart';

const double playerRunAnimationThreshold = 5;
const double playerAirAnimationThreshold = 60;

PlayerAnimationState resolvePlayerAnimationState({
  required bool usesPlatformerMovement,
  required bool grounded,
  required double horizontalVelocity,
  required double verticalVelocity,
  required bool isMoving,
}) {
  if (!usesPlatformerMovement) {
    return isMoving ? PlayerAnimationState.run : PlayerAnimationState.idle;
  }
  if (grounded) {
    return horizontalVelocity.abs() > playerRunAnimationThreshold
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
