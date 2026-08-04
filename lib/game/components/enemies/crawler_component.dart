import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

final class CrawlerComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  CrawlerComponent({
    required this.entityId,
    required super.position,
    int initialHealth = maxHealth,
    this.onOverflow,
  }) : healthState = HealthState(max: maxHealth, current: initialHealth),
       super(
         size: Vector2.all(32),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFFF6464),
         priority: 10,
       );

  static const double moveSpeed = 70;
  static const int maxHealth = 3;
  static const double overflowDelaySeconds = 0.35;

  @override
  final String entityId;
  final HealthState healthState;
  final void Function(CrawlerComponent crawler)? onOverflow;
  final Vector2 _previousPosition = Vector2.zero();

  bool _overflowStarted = false;
  double _overflowTimer = 0;

  int get health => healthState.current;
  bool get isDefeated => healthState.isDefeated;
  bool get isOverflowing => _overflowStarted;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RectangleHitbox.relative(
        Vector2.all(0.72),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  void takePulseDamage(int amount) => receiveDamage(amount);

  @override
  void receiveDamage(int amount) {
    final mutation = healthState.applyDamage(amount);
    if (mutation == HealthMutation.defeated) {
      removeFromParent();
    } else if (mutation == HealthMutation.damaged) {
      paint.color = const Color(0xFFFFFFFF);
    }
  }

  @override
  void receiveHealing(int amount) {
    final mutation = healthState.applyHealing(amount);
    if (mutation == HealthMutation.healed) {
      paint.color = const Color(0xFF36E1FF);
    } else if (mutation == HealthMutation.overflowed) {
      _overflowStarted = true;
      _overflowTimer = overflowDelaySeconds;
      paint.color = const Color(0xFFFF4FD8);
    }
  }

  @override
  void update(double dt) {
    if (_overflowStarted) {
      _overflowTimer -= dt;
      scale.setAll(1 + (overflowDelaySeconds - _overflowTimer) * 0.55);
      if (_overflowTimer <= 0) {
        onOverflow?.call(this);
        removeFromParent();
      }
      super.update(dt);
      return;
    }

    if (!game.world.isReady) {
      super.update(dt);
      return;
    }
    _previousPosition.setFrom(position);
    final direction = game.world.player.position - position;
    if (direction.length2 > 16) {
      direction.normalize();
      position += direction * (moveSpeed * dt);
    }
    if (paint.color == const Color(0xFFFFFFFF) ||
        paint.color == const Color(0xFF36E1FF)) {
      paint.color = const Color(0xFFFF6464);
    }
    super.update(dt);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is WallComponent) {
      position.setFrom(_previousPosition);
    }
    super.onCollision(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    const barHeight = 4.0;
    final maxRatio = healthState.max / healthState.overflowThreshold;
    final currentRatio = healthState.normalizedForOverflowBar;
    canvas.drawRect(
      Rect.fromLTWH(0, -8, width, barHeight),
      Paint()..color = const Color(0xFF1C2435),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -8, width * maxRatio, barHeight),
      Paint()..color = const Color(0xFF36E1FF),
    );
    if (currentRatio > maxRatio) {
      canvas.drawRect(
        Rect.fromLTWH(
          width * maxRatio,
          -8,
          width * (currentRatio - maxRatio),
          barHeight,
        ),
        Paint()..color = const Color(0xFFFF4FD8),
      );
    }
  }
}
