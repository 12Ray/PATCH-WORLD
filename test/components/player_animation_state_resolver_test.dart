import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/player/player_animation_state_resolver.dart';

void main() {
  test('legacy movement resolves only idle and run', () {
    expect(
      _resolve(usesPlatformerMovement: false, isMoving: false),
      PlayerAnimationState.idle,
    );
    expect(
      _resolve(usesPlatformerMovement: false, isMoving: true),
      PlayerAnimationState.run,
    );
  });

  test('grounded platformer movement resolves idle and run by velocity', () {
    expect(
      _resolve(grounded: true, horizontalVelocity: 10),
      PlayerAnimationState.idle,
    );
    expect(
      _resolve(grounded: true, horizontalVelocity: 10.1),
      PlayerAnimationState.run,
    );
    expect(
      _resolve(grounded: true, horizontalVelocity: -10.1),
      PlayerAnimationState.run,
    );
  });

  test('grounded run uses hysteresis near zero velocity', () {
    expect(
      _resolve(
        grounded: true,
        horizontalVelocity: 4,
        currentState: PlayerAnimationState.run,
      ),
      PlayerAnimationState.run,
    );
    expect(
      _resolve(
        grounded: true,
        horizontalVelocity: 3,
        currentState: PlayerAnimationState.run,
      ),
      PlayerAnimationState.idle,
    );
    expect(
      _resolve(
        grounded: true,
        horizontalVelocity: 4,
        currentState: PlayerAnimationState.idle,
      ),
      PlayerAnimationState.idle,
    );
  });

  test('airborne vertical velocity resolves rise apex and fall', () {
    expect(_resolve(verticalVelocity: -60.1), PlayerAnimationState.jumpRise);
    expect(_resolve(verticalVelocity: -60), PlayerAnimationState.apex);
    expect(_resolve(verticalVelocity: 0), PlayerAnimationState.apex);
    expect(_resolve(verticalVelocity: 60), PlayerAnimationState.apex);
    expect(_resolve(verticalVelocity: 60.1), PlayerAnimationState.fall);
  });
}

PlayerAnimationState _resolve({
  bool usesPlatformerMovement = true,
  bool grounded = false,
  double horizontalVelocity = 0,
  double verticalVelocity = 0,
  bool isMoving = false,
  PlayerAnimationState? currentState,
}) => resolvePlayerAnimationState(
  usesPlatformerMovement: usesPlatformerMovement,
  grounded: grounded,
  horizontalVelocity: horizontalVelocity,
  verticalVelocity: verticalVelocity,
  isMoving: isMoving,
  currentState: currentState,
);
