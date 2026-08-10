import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

enum RoomHazardStyle { spikes, laser }

final class RoomHazardComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  RoomHazardComponent({
    required super.position,
    required super.size,
    required this.style,
    required this.sourceId,
  }) : super(priority: 8);

  final RoomHazardStyle style;
  final String sourceId;
  double _phase = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(size: size));
  }

  @override
  void update(double dt) {
    _phase += dt;
    super.update(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is PlayerComponent) {
      other.takeDamage(1, causeId: sourceId);
      if (style == RoomHazardStyle.spikes) {
        other.applyExternalImpulse(Vector2(0, -260));
      }
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    final glow = .55 + math.sin(_phase * 7) * .18;
    switch (style) {
      case RoomHazardStyle.spikes:
        final path = Path();
        const spikeWidth = 16.0;
        for (double x = 0; x < size.x; x += spikeWidth) {
          path
            ..moveTo(x, size.y)
            ..lineTo(math.min(x + spikeWidth / 2, size.x), 0)
            ..lineTo(math.min(x + spikeWidth, size.x), size.y)
            ..close();
        }
        canvas.drawPath(
          path,
          Paint()..color = Color.fromRGBO(255, 79, 216, glow),
        );
      case RoomHazardStyle.laser:
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.x / 2, size.y / 2),
            width: math.min(6, size.x),
            height: size.y,
          ),
          Paint()
            ..color = Color.fromRGBO(255, 79, 216, glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        for (final y in <double>[0, size.y - 8]) {
          canvas.drawRect(
            Rect.fromLTWH(0, y, size.x, 8),
            Paint()..color = const Color(0xFF6F315F),
          );
        }
    }
    super.render(canvas);
  }
}

final class JumpPadComponent extends PositionComponent with CollisionCallbacks {
  JumpPadComponent({required super.position})
    : super(size: Vector2(54, 12), priority: 7);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(size: size));
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is PlayerComponent) {
      other.applyExternalImpulse(Vector2(0, -520));
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
      Paint()..color = const Color(0xFF145E72),
    );
    for (final x in <double>[14, 27, 40]) {
      final arrow = Path()
        ..moveTo(x - 5, 8)
        ..lineTo(x, 3)
        ..lineTo(x + 5, 8);
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF36E1FF),
      );
    }
    super.render(canvas);
  }
}

final class CheckpointBeaconComponent extends PositionComponent {
  CheckpointBeaconComponent({required super.position, required this.index})
    : super(size: Vector2(34, 58), anchor: Anchor.bottomCenter, priority: 6);

  final int index;
  double _phase = 0;

  @override
  void update(double dt) {
    _phase += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final pulse = 10 + math.sin(_phase * 4 + index) * 2;
    final center = Offset(size.x / 2, 17);
    canvas.drawCircle(
      center,
      pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xAAFFD35A),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 4, 27, 8, 25),
      Paint()..color = const Color(0xFF496178),
    );
    canvas.drawRect(
      Rect.fromLTWH(4, 50, size.x - 8, 8),
      Paint()..color = const Color(0xFF25304A),
    );
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFFFFD35A));
    super.render(canvas);
  }
}
