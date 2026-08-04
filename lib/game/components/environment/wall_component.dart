import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

final class WallComponent extends RectangleComponent {
  WallComponent({required super.position, required super.size})
    : super(paint: Paint()..color = const Color(0xFF25304A));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(collisionType: CollisionType.passive));
  }
}
