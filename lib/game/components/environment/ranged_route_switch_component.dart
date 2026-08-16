import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

/// A weapon-hit switch used by optional gun routes.
final class RangedRouteSwitchComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  RangedRouteSwitchComponent({
    required super.position,
    required this.onActivated,
    this.routeEntityId = 'environment.damageLab.rangedRouteSwitch',
    this.accentColor = const Color(0xFF36E1FF),
  }) : super(size: Vector2.all(42), anchor: Anchor.center, priority: 18);

  final VoidCallback onActivated;
  final String routeEntityId;
  final Color accentColor;
  bool _activated = false;

  @override
  String get entityId => routeEntityId;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RectangleHitbox.relative(
        Vector2.all(.82),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  @override
  void receiveDamage(int amount) => _activate(amount);

  @override
  void receiveHealing(int amount) => _activate(amount);

  void _activate(int amount) {
    if (_activated || amount <= 0) return;
    _activated = true;
    onActivated();
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final bounds = Rect.fromLTWH(2, 2, size.x - 4, size.y - 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(7)),
      Paint()..color = const Color(0xFF263055),
    );
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      10,
      Paint()..color = accentColor,
    );
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFD35A),
    );
    super.render(canvas);
  }
}
