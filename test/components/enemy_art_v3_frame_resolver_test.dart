import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_art_v3_frame_resolver.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_combat_state.dart';

void main() {
  test('signature frames map directly to combat timeline phases', () {
    expect(_frame(EnemyCombatState.telegraph), 4);
    expect(_frame(EnemyCombatState.attacking), 5);
    expect(_frame(EnemyCombatState.recovering), inInclusiveRange(6, 7));
  });

  test('locomotion loops only within the first four frames', () {
    for (var index = 0; index < 40; index += 1) {
      final frame = resolveArtV3EnemyFrame(
        state: index.isEven ? EnemyCombatState.idle : EnemyCombatState.moving,
        visualClock: index / 20,
        archetypeIndex: index % 15,
      );
      expect(frame, inInclusiveRange(0, 3));
    }
  });

  test('legacy hurt and defeat key poses remain explicit fallbacks', () {
    for (final state in <EnemyCombatState>[
      EnemyCombatState.hurt,
      EnemyCombatState.staggered,
      EnemyCombatState.overflowing,
      EnemyCombatState.defeated,
    ]) {
      expect(_frame(state), -1);
    }
  });
}

int _frame(EnemyCombatState state) =>
    resolveArtV3EnemyFrame(state: state, visualClock: 0.05, archetypeIndex: 0);
