import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_art_v3_frame_resolver.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_combat_state.dart';

void main() {
  test('tier and special attacks use their Combat Motion v2 action pose', () {
    for (final motionFrame in <int>[4, 5, 6, 7]) {
      expect(
        usesCombatMotionAttackFrame(
          state: EnemyCombatState.attacking,
          motionFrame: motionFrame,
        ),
        isTrue,
      );
    }
    expect(
      usesCombatMotionAttackFrame(
        state: EnemyCombatState.attacking,
        motionFrame: 3,
      ),
      isFalse,
      reason: 'signature attacks keep the authored Art v3 active frame',
    );
    expect(
      usesCombatMotionAttackFrame(
        state: EnemyCombatState.recovering,
        motionFrame: 7,
      ),
      isFalse,
      reason: 'recovery returns to the authored Art v3 recovery frames',
    );
  });

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
