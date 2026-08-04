import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

/// A short-lived reward that turns enemy resolution into visible momentum.
final class DataShardComponent extends RectangleComponent
    with HasGameReference<PatchWorldGame> {
  DataShardComponent({
    required super.position,
    required this.scatterDirection,
    required this.isCorrupted,
  }) : super(
         size: Vector2.all(7),
         anchor: Anchor.center,
         angle: math.pi / 4,
         paint: Paint()
           ..color = isCorrupted
               ? const Color(0xFFFF4FD8)
               : const Color(0xFF36E1FF),
         priority: 28,
       );

  final Vector2 scatterDirection;
  final bool isCorrupted;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (!game.world.isReady) {
      removeFromParent();
      return;
    }

    if (_age < 0.18) {
      position += scatterDirection * (85 * dt);
    } else {
      final delta = game.world.player.position - position;
      if (delta.length2 < 18 * 18) {
        game.world.player.absorbDataShard();
        removeFromParent();
        return;
      }
      if (delta.length2 > 0) {
        delta.normalize();
        final speed = 150 + math.min(220, (_age - 0.18) * 260);
        position += delta * (speed * dt);
      }
    }
    scale.setAll(0.82 + math.sin(_age * 14).abs() * 0.32);
    if (_age > 2.2) removeFromParent();
    super.update(dt);
  }
}
