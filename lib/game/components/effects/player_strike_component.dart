import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

final class PlayerStrikeComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  PlayerStrikeComponent({
    required super.position,
    required super.size,
    required this.sourceId,
    this.damage = 1,
    this.activeSeconds = 0.12,
    this.strikeColor = const Color(0x7736E1FF),
    double rotation = 0,
  }) : super(anchor: Anchor.center, priority: 31, angle: rotation);

  final String sourceId;
  final int damage;
  final double activeSeconds;
  final Color strikeColor;
  final Set<CombatTarget> _hitTargets = <CombatTarget>{};
  late double _remaining = activeSeconds;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RectangleHitbox.relative(
        Vector2.all(1),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  @override
  void update(double dt) {
    _applyToOverlappingTargets();
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
    super.update(dt);
  }

  void _applyToOverlappingTargets() {
    if (!isMounted) return;
    final cosine = math.cos(-angle);
    final sine = math.sin(-angle);
    for (final component in game.world.activeCombatTargets) {
      final target = component as CombatTarget;
      if (_hitTargets.contains(target)) continue;
      final delta = component.position - position;
      final localX = delta.x * cosine - delta.y * sine;
      final localY = delta.x * sine + delta.y * cosine;
      if (localX.abs() > size.x / 2 + component.size.x / 2 ||
          localY.abs() > size.y / 2 + component.size.y / 2) {
        continue;
      }
      _commitTarget(target);
    }
  }

  void _commitTarget(CombatTarget target) {
    if (!_hitTargets.add(target)) return;
    game.combatSystem.applyPlayerAttack(
      target,
      sourceId: sourceId,
      amount: damage,
    );
    final component = target as PositionComponent;
    game.triggerPlayerWeaponImpactFeedback(
      sourceId: sourceId,
      position: component.position,
      direction: Vector2(math.cos(angle), math.sin(angle)),
      damage: damage,
    );
  }

  @override
  void render(Canvas canvas) {
    final progress = (_remaining / activeSeconds).clamp(0, 1).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(8),
      ),
      Paint()..color = strikeColor.withValues(alpha: progress * 0.55),
    );
    super.render(canvas);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is CombatTarget) {
      final target = other as CombatTarget;
      _commitTarget(target);
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
