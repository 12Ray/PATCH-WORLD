import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/phase_hound_component.dart';

void main() {
  test('phase hound locks a readable dash through all four states', () {
    var target = Vector2(220, 0);
    final hound = PhaseHoundComponent(
      entityId: 'hound-test',
      position: Vector2.zero(),
      targetPosition: () => target,
      onDefeated: () {},
    );

    hound.update(1.01);
    expect(hound.state, PhaseHoundState.telegraph);
    final locked = hound.lockedDirection;
    target = Vector2(-220, 0);
    hound.update(0.30);
    expect(hound.state, PhaseHoundState.telegraph);
    expect(hound.lockedDirection.x, closeTo(locked.x, 0.001));
    expect(hound.lockedDirection.y, closeTo(locked.y, 0.001));

    hound.update(0.36);
    expect(hound.state, PhaseHoundState.dash);
    expect(hound.claimDashHit(), isTrue);
    expect(hound.claimDashHit(), isFalse);
    final beforeDash = hound.position.clone();
    hound.update(0.10);
    expect(hound.position.distanceTo(beforeDash), closeTo(33, 0.001));
    hound.update(0.23);
    expect(hound.state, PhaseHoundState.recovery);
    hound.update(0.86);
    expect(hound.state, PhaseHoundState.stalk);
  });

  test('phase hound has three health and reports defeat once', () {
    var defeats = 0;
    final hound = PhaseHoundComponent(
      entityId: 'hound-health',
      position: Vector2.zero(),
      targetPosition: () => Vector2(200, 0),
      onDefeated: () => defeats += 1,
    );

    hound.receiveDamage(2);
    expect(hound.healthState.current, 1);
    hound.receiveDamage(1);
    hound.receiveDamage(3);

    expect(hound.healthState.isDefeated, isTrue);
    expect(defeats, 1);
  });
}
