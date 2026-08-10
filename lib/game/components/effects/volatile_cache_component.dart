import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:patch_world/game/patch_world_game.dart';

/// A short-lived spatial objective that rewards crossing a dangerous arena.
final class VolatileCacheComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  VolatileCacheComponent({
    required super.position,
    required this.onCollected,
    required this.onExpired,
    this.playerPosition,
  }) : super(size: Vector2.all(76), anchor: Anchor.center, priority: 35);

  static const double lifetimeSeconds = 12;
  static const double collectionRadius = 28;

  final void Function(Vector2 position) onCollected;
  final void Function(Vector2 position) onExpired;
  final Vector2 Function()? playerPosition;

  double remainingSeconds = lifetimeSeconds;
  double _age = 0;
  bool _resolved = false;

  bool get isResolved => _resolved;

  @override
  void update(double dt) {
    final simulationDt = isMounted ? game.clock.simulationDt : dt;
    if (_resolved || simulationDt <= 0) {
      super.update(dt);
      return;
    }
    _age += simulationDt;
    remainingSeconds = math.max(0, remainingSeconds - simulationDt);
    final target = playerPosition?.call() ?? game.world.player.position;
    if (position.distanceTo(target) <= collectionRadius) {
      _resolve(onCollected);
    } else if (remainingSeconds == 0) {
      _resolve(onExpired);
    }
    super.update(dt);
  }

  void _resolve(void Function(Vector2 position) callback) {
    if (_resolved) return;
    _resolved = true;
    callback(position.clone());
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final progress = (remainingSeconds / lifetimeSeconds).clamp(0.0, 1.0);
    final pulse = 1 + math.sin(_age * 8) * 0.08;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulse);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 24, height: 24),
      Paint()..color = const Color(0xFFFFC857),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 12, height: 12),
      Paint()..color = const Color(0xFF111827),
    );
    canvas.restore();
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 31),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = progress < 0.25
            ? const Color(0xFFFF6464)
            : const Color(0xFF36E1FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: isMounted
            ? game.localization.text(
                'unit.secondsShort',
                parameters: <String, Object>{'value': remainingSeconds.ceil()},
              )
            : '${remainingSeconds.ceil()}s',
        style: const TextStyle(
          color: Color(0xFFF4F7FF),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, size.y - painter.height),
    );
  }
}
