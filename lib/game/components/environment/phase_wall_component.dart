import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

final class PhaseWallComponent extends RectangleComponent {
  PhaseWallComponent({required super.position, required super.size})
    : super(paint: Paint()..color = const Color(0xAAFF4FD8), priority: 2);

  RectangleHitbox? _hitbox;
  bool _solid = true;
  @override
  bool get isSolid => _solid;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _attachHitbox();
  }

  Future<void> setSolid(bool value) async {
    if (_solid == value) return;
    _solid = value;
    if (value) {
      paint.color = const Color(0xAAFF4FD8);
      await _attachHitbox();
    } else {
      paint.color = const Color(0x22FF4FD8);
      _hitbox?.removeFromParent();
      _hitbox = null;
    }
  }

  Future<void> _attachHitbox() async {
    if (_hitbox != null) return;
    final hitbox = RectangleHitbox(collisionType: CollisionType.passive);
    _hitbox = hitbox;
    await add(hitbox);
  }
}
