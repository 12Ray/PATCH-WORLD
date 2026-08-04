import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/phase_hound_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';

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
    expect(hound.stateCue, 'LOCK');
    final locked = hound.lockedDirection;
    target = Vector2(-220, 0);
    hound.update(0.30);
    expect(hound.state, PhaseHoundState.telegraph);
    expect(hound.lockedDirection.x, closeTo(locked.x, 0.001));
    expect(hound.lockedDirection.y, closeTo(locked.y, 0.001));

    hound.update(0.36);
    expect(hound.state, PhaseHoundState.dash);
    expect(hound.stateCue, isNull);
    expect(hound.claimDashHit(), isTrue);
    expect(hound.claimDashHit(), isFalse);
    final beforeDash = hound.position.clone();
    hound.update(0.10);
    expect(hound.position.distanceTo(beforeDash), closeTo(33, 0.001));
    hound.update(0.23);
    expect(hound.state, PhaseHoundState.recovery);
    expect(hound.stateCue, 'BREAK +1');
    hound.update(0.86);
    expect(hound.state, PhaseHoundState.stalk);
    expect(hound.stateCue, isNull);
  });

  test('recovery is a one-point damage break window', () {
    final normal = PhaseHoundComponent(
      entityId: 'hound-normal-damage',
      position: Vector2.zero(),
      targetPosition: () => Vector2(220, 0),
      onDefeated: () {},
    );
    normal.receiveDamage(1);
    expect(normal.healthState.current, 2);

    var defeats = 0;
    final broken = PhaseHoundComponent(
      entityId: 'hound-break-damage',
      position: Vector2.zero(),
      targetPosition: () => Vector2(220, 0),
      onDefeated: () => defeats += 1,
    );
    broken.update(1.01);
    broken.update(0.66);
    broken.update(0.33);
    expect(broken.state, PhaseHoundState.recovery);

    broken.receiveDamage(1);
    expect(broken.healthState.current, 1);
    broken.receiveDamage(1);
    broken.receiveDamage(1);
    expect(broken.healthState.isDefeated, isTrue);
    expect(defeats, 1);
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

  test('dash path geometry preserves hit and perfect dodge bands', () {
    final start = Vector2.zero();
    final end = Vector2(100, 0);

    expect(
      PhaseHoundComponent.distanceToDashPath(
        target: Vector2(50, 30),
        start: start,
        end: end,
      ),
      PhaseHoundComponent.dashHitRadius,
    );
    expect(
      PhaseHoundComponent.distanceToDashPath(
        target: Vector2(50, 70),
        start: start,
        end: end,
      ),
      PhaseHoundComponent.perfectDodgeRadius,
    );
    expect(
      PhaseHoundComponent.distanceToDashPath(
        target: Vector2(140, 0),
        start: start,
        end: end,
      ),
      40,
    );
  });

  test('near dash reports one dodge but hits and wall aborts do not', () {
    var target = Vector2(220, 0);
    var dodges = 0;
    final hound = PhaseHoundComponent(
      entityId: 'hound-dodge',
      position: Vector2.zero(),
      targetPosition: () => target,
      onPerfectDodge: () => dodges += 1,
      onDefeated: () {},
    );

    hound.update(1.01);
    final locked = hound.lockedDirection;
    hound.update(0.66);
    final perpendicular = Vector2(-locked.y, locked.x);
    target = hound.position + locked * 50 + perpendicular * 50;
    hound.update(0.33);
    expect(hound.state, PhaseHoundState.recovery);
    expect(dodges, 1);
    hound.update(0.1);
    expect(dodges, 1);

    target = Vector2(220, 0);
    final hitHound = PhaseHoundComponent(
      entityId: 'hound-hit-no-dodge',
      position: Vector2.zero(),
      targetPosition: () => target,
      onPerfectDodge: () => dodges += 1,
      onDefeated: () {},
    );
    hitHound.update(1.01);
    final hitLocked = hitHound.lockedDirection;
    hitHound.update(0.66);
    target =
        hitHound.position +
        hitLocked * 50 +
        Vector2(-hitLocked.y, hitLocked.x) * 50;
    expect(hitHound.claimDashHit(), isTrue);
    hitHound.update(0.33);
    expect(dodges, 1);

    target = Vector2(220, 0);
    final blockedHound = PhaseHoundComponent(
      entityId: 'hound-wall-no-dodge',
      position: Vector2.zero(),
      targetPosition: () => target,
      onPerfectDodge: () => dodges += 1,
      onDefeated: () {},
    );
    blockedHound.update(1.01);
    final blockedLocked = blockedHound.lockedDirection;
    blockedHound.update(0.66);
    target =
        blockedHound.position +
        blockedLocked * 30 +
        Vector2(-blockedLocked.y, blockedLocked.x) * 50;
    blockedHound.update(0.1);
    blockedHound.onCollision(
      <Vector2>{},
      WallComponent(position: Vector2.zero(), size: Vector2.all(20)),
    );
    expect(blockedHound.state, PhaseHoundState.recovery);
    expect(dodges, 1);
  });
}
