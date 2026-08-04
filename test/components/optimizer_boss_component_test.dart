import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';

void main() {
  test('optimizer enters predict, perfect, then stability overflow', () {
    var perfectEntries = 0;
    final boss = OptimizerBossComponent(
      position: Vector2.zero(),
      onPerfectStateEntered: () => perfectEntries += 1,
      onDefeated: () {},
    );
    boss.receiveDamage(7);
    expect(boss.phase, OptimizerPhase.predict);
    boss.receiveDamage(7);
    expect(boss.phase, OptimizerPhase.perfect);
    expect(perfectEntries, 1);
    for (var i = 0; i < 4; i += 1) {
      boss.receiveHealing(1);
    }
    expect(boss.stability.current, 150);
    expect(boss.phase, OptimizerPhase.overflow);
  });
}
