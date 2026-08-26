import 'package:patch_world/game/components/enemies/platformer/enemy_combat_state.dart';

/// Combat Motion v2 owns the four action-specific poses (frames 4-7).
/// Art v3 remains responsible for locomotion, the shared anticipation pose,
/// signature attack animation, and recovery animation.
bool usesCombatMotionAttackFrame({
  required EnemyCombatState state,
  required int motionFrame,
}) => state == EnemyCombatState.attacking && motionFrame >= 4;

int resolveArtV3EnemyFrame({
  required EnemyCombatState state,
  required double stateElapsed,
  required int archetypeIndex,
}) {
  final elapsed = stateElapsed.isFinite && stateElapsed >= 0
      ? stateElapsed
      : 0.0;
  return switch (state) {
    EnemyCombatState.idle => ((elapsed * 4).floor() + archetypeIndex) % 4,
    EnemyCombatState.moving => ((elapsed * 8).floor() + archetypeIndex) % 4,
    EnemyCombatState.telegraph => 4,
    EnemyCombatState.attacking => 5,
    EnemyCombatState.recovering => 6 + (elapsed * 6).floor().clamp(0, 1),
    EnemyCombatState.hurt ||
    EnemyCombatState.staggered ||
    EnemyCombatState.overflowing ||
    EnemyCombatState.defeated => -1,
  };
}
