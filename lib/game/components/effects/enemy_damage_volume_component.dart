import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/player/player_component.dart';

/// A short-lived hitbox used by telegraphed enemy melee and shockwave attacks.
/// It can damage the player at most once during its active lifetime.
final class EnemyDamageVolumeComponent extends PositionComponent
    with CollisionCallbacks {
  EnemyDamageVolumeComponent({
    required super.position,
    required super.size,
    required this.sourceId,
    this.damage = 1,
    this.activeSeconds = 0.12,
    this.volumeColor = const Color(0x66FF4FD8),
  }) : super(anchor: Anchor.center, priority: 24);

  final String sourceId;
  final int damage;
  final double activeSeconds;
  final Color volumeColor;
  double _remaining = 0;
  bool _resolved = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _remaining = activeSeconds;
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
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = volumeColor,
    );
    super.render(canvas);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (!_resolved && other is PlayerComponent) {
      _resolved = true;
      other.takeDamage(damage, causeId: sourceId);
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
