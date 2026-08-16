import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

final class WallComponent extends RectangleComponent {
  WallComponent({
    required super.position,
    required super.size,
    Color color = const Color(0xFF25304A),
  }) : super(paint: Paint()..color = color);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(collisionType: CollisionType.passive));
  }
}
