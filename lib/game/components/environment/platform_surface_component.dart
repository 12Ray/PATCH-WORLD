import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

enum PlatformSurfaceStyle { damage, temporal, collision, optimizer }

class PlatformSurfaceComponent extends RectangleComponent {
  PlatformSurfaceComponent({
    required super.position,
    required super.size,
    this.isBoundary = false,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(
         paint: Paint()
           ..color = switch (style) {
             PlatformSurfaceStyle.damage => const Color(0xFF25304A),
             PlatformSurfaceStyle.temporal => const Color(0xFF29284C),
             PlatformSurfaceStyle.collision => const Color(0xFF183E47),
             PlatformSurfaceStyle.optimizer => const Color(0xFF242338),
           },
         priority: 2,
       );

  final bool isBoundary;
  final PlatformSurfaceStyle style;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);
  @override
  bool get isSolid => !isRemoving;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (isBoundary) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, 4),
      Paint()..color = _accentColor,
    );
    for (double x = 10; x < size.x; x += 24) {
      canvas.drawRect(
        Rect.fromLTWH(x, 9, 10, mathMin(3, size.y - 9)),
        Paint()..color = _accentColor.withAlpha(85),
      );
    }
    if (style == PlatformSurfaceStyle.temporal) {
      for (double x = 20; x < size.x; x += 42) {
        canvas.drawCircle(
          Offset(x, mathMin(14, size.y - 3)),
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0x889D8CFF),
        );
      }
    } else if (style == PlatformSurfaceStyle.collision) {
      for (double x = 16; x < size.x; x += 38) {
        canvas.drawLine(
          Offset(x, 8),
          Offset(mathMin(x + 12, size.x), mathMin(18, size.y - 2)),
          Paint()
            ..strokeWidth = 2
            ..color = const Color(0x88FF4FD8),
        );
      }
    } else if (style == PlatformSurfaceStyle.optimizer) {
      for (double x = 14; x < size.x; x += 32) {
        canvas.drawRect(
          Rect.fromLTWH(x, 9, 14, mathMin(4, size.y - 9)),
          Paint()..color = const Color(0x88FF4FD8),
        );
        canvas.drawCircle(
          Offset(x + 7, mathMin(18, size.y - 3)),
          2.5,
          Paint()..color = const Color(0xAA36E1FF),
        );
      }
    }
  }

  Color get _accentColor => switch (style) {
    PlatformSurfaceStyle.damage => const Color(0xFF36E1FF),
    PlatformSurfaceStyle.temporal => const Color(0xFF9D8CFF),
    PlatformSurfaceStyle.collision => const Color(0xFF2CF2C8),
    PlatformSurfaceStyle.optimizer => const Color(0xFFF4F7FF),
  };

  double mathMin(double a, double b) => a < b ? a : b;
}

final class MovingPlatformComponent extends PlatformSurfaceComponent {
  MovingPlatformComponent({
    required Vector2 start,
    required this.end,
    required super.size,
    required this.periodSeconds,
    super.style,
  }) : _start = start.clone(),
       super(position: start);

  final Vector2 _start;
  final Vector2 end;
  final double periodSeconds;
  double _elapsed = 0;

  @override
  void update(double dt) {
    _elapsed += dt;
    final phase = (_elapsed / periodSeconds) * math.pi * 2;
    final t = (math.sin(phase) + 1) / 2;
    position.setFrom(_start + (end - _start) * t);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      5,
      Paint()..color = const Color(0xFFFFD35A),
    );
  }
}

final class ConveyorPlatformComponent extends PlatformSurfaceComponent {
  ConveyorPlatformComponent({
    required super.position,
    required super.size,
    required this.direction,
    super.style,
  });

  final double direction;
  double _phase = 0;

  @override
  void update(double dt) {
    _phase = (_phase + dt * direction * 42) % 24;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (double x = _phase - 24; x < size.x; x += 24) {
      final arrow = Path()
        ..moveTo(x, size.y / 2 - 4)
        ..lineTo(x + 9 * direction, size.y / 2)
        ..lineTo(x, size.y / 2 + 4);
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xAA36E1FF),
      );
    }
  }
}

final class BreakablePlatformComponent extends PlatformSurfaceComponent
    with HasGameReference<PatchWorldGame> {
  BreakablePlatformComponent({
    required super.position,
    required super.size,
    super.style,
    this.breakDelay = 0.7,
    this.restoreDelay = 3.2,
  });

  final double breakDelay;
  final double restoreDelay;
  double _standingTime = 0;
  double _brokenTime = 0;
  bool _broken = false;

  @override
  bool get isSolid => !_broken && super.isSolid;

  @override
  void update(double dt) {
    if (_broken) {
      _brokenTime += dt;
      if (_brokenTime >= restoreDelay) {
        _broken = false;
        _brokenTime = 0;
      }
      super.update(dt);
      return;
    }
    if (game.world.isReady) {
      final player = game.world.player;
      final feet = player.position.y + player.size.y / 2;
      final standing =
          player.position.x >= position.x &&
          player.position.x <= position.x + size.x &&
          (feet - position.y).abs() <= 5;
      _standingTime = standing ? _standingTime + dt : 0;
      if (_standingTime >= breakDelay) {
        _broken = true;
        _standingTime = 0;
      }
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_broken) return;
    super.render(canvas);
    final crack = (_standingTime / breakDelay).clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(size.x * .35, 4),
      Offset(size.x * (.45 + .25 * crack), size.y - 3),
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFFFFD35A),
    );
  }
}

final class DamagePitComponent extends RectangleComponent {
  DamagePitComponent({
    required super.position,
    required super.size,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(
         paint: Paint()
           ..color = switch (style) {
             PlatformSurfaceStyle.damage => const Color(0xFF260B2E),
             PlatformSurfaceStyle.temporal => const Color(0xFF15143A),
             PlatformSurfaceStyle.collision => const Color(0xFF092F37),
             PlatformSurfaceStyle.optimizer => const Color(0xFF220C28),
           },
         priority: 1,
       );

  final PlatformSurfaceStyle style;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final stripe = Paint()
      ..color = switch (style) {
        PlatformSurfaceStyle.damage => const Color(0xFFEB4BD8),
        PlatformSurfaceStyle.temporal => const Color(0xFF9D8CFF),
        PlatformSurfaceStyle.collision => const Color(0xFF2CF2C8),
        PlatformSurfaceStyle.optimizer => const Color(0xFFFF4FD8),
      };
    for (double x = -20; x < size.x + 20; x += 20) {
      canvas.drawLine(
        Offset(x, 4),
        Offset(x + 14, 18),
        stripe..strokeWidth = 3,
      );
    }
  }
}
