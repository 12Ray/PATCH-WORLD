import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class CrawlerComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  CrawlerComponent({required this.entityId, required super.position})
    : super(
        size: Vector2.all(32),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFFFF6464),
        priority: 10,
      );

  static const double moveSpeed = 70;
  static const int maxHealth = 3;

  final String entityId;
  final Vector2 _previousPosition = Vector2.zero();

  int health = maxHealth;
  bool get isDefeated => health == 0;

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

  void takePulseDamage(int amount) {
    if (amount <= 0 || isRemoving) {
      return;
    }

    health = math.max(0, health - amount);
    paint.color = const Color(0xFFFFFFFF);
    if (health == 0) {
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
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

    if (paint.color == const Color(0xFFFFFFFF)) {
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
    final ratio = health / maxHealth;
    canvas.drawRect(
      Rect.fromLTWH(0, -8, width, barHeight),
      Paint()..color = const Color(0xFF1C2435),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -8, width * ratio, barHeight),
      Paint()..color = const Color(0xFFFF6464),
    );
  }
}
