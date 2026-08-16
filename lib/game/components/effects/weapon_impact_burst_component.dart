import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

final class WeaponImpactBurstComponent extends PositionComponent {
  WeaponImpactBurstComponent({
    required super.position,
    required this.weapon,
    required Vector2 direction,
    this.heavy = false,
  }) : direction = direction.length2 == 0
           ? Vector2(1, 0)
           : direction.normalized(),
       _duration = heavy ? .26 : .18,
       super(
         size: Vector2.all(heavy ? 132 : 104),
         anchor: Anchor.center,
         priority: 34,
       ) {
    _remaining = _duration;
  }

  final PlayerWeapon weapon;
  final Vector2 direction;
  final bool heavy;
  final double _duration;
  late double _remaining;

  Color get _color => switch (weapon) {
    PlayerWeapon.sword => const Color(0xFF36E1FF),
    PlayerWeapon.gauntlet => const Color(0xFFFF4FD8),
    PlayerWeapon.gun => const Color(0xFFFFC857),
  };

  @override
  void update(double dt) {
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (1 - _remaining / _duration).clamp(0.0, 1.0);
    final fade = (1 - progress).clamp(0.0, 1.0);
    final center = Offset(width / 2, height / 2);
    final radius = (heavy ? 16 : 10) + progress * (heavy ? 46 : 32);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (heavy ? 5 : 3) * fade
        ..color = _color.withValues(alpha: fade * .85),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.atan2(direction.y, direction.x));
    final streakPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = heavy ? 6 : 4
      ..color = _color.withValues(alpha: fade);
    final length = (heavy ? 58 : 42) * (1 + progress * .25);
    for (var index = -1; index <= 1; index += 1) {
      final offset = index * (heavy ? 11.0 : 8.0);
      canvas.drawLine(
        Offset(-length * .62, offset),
        Offset(length * .38, offset * .35),
        streakPaint,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      heavy ? 6 : 4,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: fade),
    );
    super.render(canvas);
  }
}
