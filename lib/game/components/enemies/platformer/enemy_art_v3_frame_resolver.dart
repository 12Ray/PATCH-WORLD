import 'package:patch_world/game/components/enemies/platformer/enemy_combat_state.dart';

int resolveArtV3EnemyFrame({
  required EnemyCombatState state,
  required double visualClock,
  required int archetypeIndex,
}) => switch (state) {
  EnemyCombatState.idle ||
  EnemyCombatState.moving => ((visualClock * 8).floor() + archetypeIndex) % 4,
  EnemyCombatState.telegraph => 4,
  EnemyCombatState.attacking => 5,
  EnemyCombatState.recovering => 6 + (visualClock * 10).floor() % 2,
  EnemyCombatState.hurt ||
  EnemyCombatState.staggered ||
  EnemyCombatState.overflowing ||
  EnemyCombatState.defeated => -1,
};
