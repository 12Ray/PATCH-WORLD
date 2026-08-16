import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class SurvivalHazardZoneComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  SurvivalHazardZoneComponent({
    required super.position,
    required super.size,
    required this.hazardId,
    this.damageInterval = .9,
  }) : super(paint: Paint()..color = const Color(0x35FF4FD8), priority: 3);

  final String hazardId;
  final double damageInterval;
  double _damageCooldown = 0;
  double _phase = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    _phase += game.clock.simulationDt;
    _damageCooldown = math.max(0, _damageCooldown - game.clock.playerStatusDt);
    super.update(dt);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is PlayerComponent && _damageCooldown <= 0) {
      _damageCooldown = damageInterval;
      other.takeDamage(1, causeId: 'hazard.survival.$hazardId');
    }
    super.onCollision(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    final pulse = .25 + (math.sin(_phase * 4) + 1) * .12;
    canvas.drawRect(
      size.toRect(),
      Paint()..color = const Color(0xFFFF4FD8).withValues(alpha: pulse),
    );
    for (var x = -size.y; x < size.x; x += 28) {
      canvas.drawLine(
        Offset(x, size.y),
        Offset(x + size.y, 0),
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0x6636E1FF),
      );
    }
    super.render(canvas);
  }
}

/// A location objective embedded in the arena. Holding a relay for 1.4s heals
/// one integrity point, then the relay needs thirty seconds to reboot.
final class SurvivalRelayPadComponent extends CircleComponent
    with HasGameReference<PatchWorldGame> {
  SurvivalRelayPadComponent({required super.position, required this.relayId})
    : super(
        radius: 34,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x1836E1FF),
        priority: 4,
      );

  final String relayId;
  double _charge = 0;
  double _cooldown = 0;

  bool get online => _cooldown <= 0;
  double get chargeProgress => (_charge / 1.4).clamp(0, 1);

  @override
  void update(double dt) {
    final statusDt = game.clock.playerStatusDt;
    _cooldown = math.max(0, _cooldown - statusDt);
    if (!online) {
      _charge = 0;
      super.update(dt);
      return;
    }
    final player = game.world.player;
    if (player.position.distanceTo(position) <= 48) {
      _charge += statusDt;
      if (_charge >= 1.4) {
        _charge = 0;
        _cooldown = 30;
        player.restoreIntegrity(1);
        game.survivalRun.bonusScore += 180;
        game.triggerImpactFeedback();
      }
    } else {
      _charge = math.max(0, _charge - statusDt * 1.5);
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    final color = online ? const Color(0xFF36E1FF) : const Color(0xFF596780);
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: .72),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -math.pi / 2,
      math.pi * 2 * chargeProgress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF45F3A6),
    );
    super.render(canvas);
  }
}
