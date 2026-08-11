import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

enum PlatformSurfaceStyle { damage, temporal, collision, optimizer }

extension PlatformSurfaceTheme on PlatformSurfaceStyle {
  String get assetSlug => name;

  Color get bodyColor => switch (this) {
    PlatformSurfaceStyle.damage => const Color(0xFF131C2D),
    PlatformSurfaceStyle.temporal => const Color(0xFF1B1932),
    PlatformSurfaceStyle.collision => const Color(0xFF102A35),
    PlatformSurfaceStyle.optimizer => const Color(0xFF242338),
  };

  Color get bodyHighlight => switch (this) {
    PlatformSurfaceStyle.damage => const Color(0xFF34445D),
    PlatformSurfaceStyle.temporal => const Color(0xFF454064),
    PlatformSurfaceStyle.collision => const Color(0xFF24536A),
    PlatformSurfaceStyle.optimizer => const Color(0xFF55516C),
  };

  Color get accentColor => switch (this) {
    PlatformSurfaceStyle.damage => const Color(0xFF36E1FF),
    PlatformSurfaceStyle.temporal => const Color(0xFF9D8CFF),
    PlatformSurfaceStyle.collision => const Color(0xFF2CF2C8),
    PlatformSurfaceStyle.optimizer => const Color(0xFFF4F7FF),
  };

  Color get secondaryAccent => switch (this) {
    PlatformSurfaceStyle.damage => const Color(0xFFFF4FD8),
    PlatformSurfaceStyle.temporal => const Color(0xFFFF4FD8),
    PlatformSurfaceStyle.collision => const Color(0xFFFF4FD8),
    PlatformSurfaceStyle.optimizer => const Color(0xFF36E1FF),
  };
}

class PlatformSurfaceComponent extends RectangleComponent
    with HasGameReference<PatchWorldGame> {
  PlatformSurfaceComponent({
    required super.position,
    required super.size,
    this.isBoundary = false,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(paint: Paint()..color = style.bodyColor, priority: 2);

  final bool isBoundary;
  final PlatformSurfaceStyle style;
  Image? _foregroundImage;

  int get foregroundFrameIndex => size.y > size.x * .72 ? 1 : 0;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);
  @override
  bool get isSolid => !isRemoving;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    unawaited(_loadForeground());
  }

  Future<void> _loadForeground() async {
    try {
      final image = await game.images.load(
        'sprites/art_v3/environment/${style.assetSlug}-foreground.png',
      );
      if (!isRemoving) _foregroundImage = image;
    } catch (_) {
      // The procedural material remains the fallback for a missing skin.
    }
  }

  @override
  void render(Canvas canvas) {
    if (isBoundary) return;
    final bounds = size.toRect();
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, size.y), <Color>[
          style.bodyHighlight,
          style.bodyColor,
        ]),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, math.max(0, size.y - 4), size.x, math.min(4, size.y)),
      Paint()..color = style.secondaryAccent.withAlpha(60),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, 4),
      Paint()
        ..color = style.accentColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawLine(
      Offset(0, math.min(7, size.y - 1)),
      Offset(size.x, math.min(7, size.y - 1)),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0xAA07101C),
    );
    for (double x = 8; x < size.x; x += 32) {
      _drawSurfaceModule(canvas, x);
    }
    _drawForegroundSkin(canvas);
  }

  void _drawForegroundSkin(Canvas canvas) {
    final image = _foregroundImage;
    if (image == null || size.x <= 0 || size.y <= 0) return;
    const sourceWidth = 384.0;
    const sourceHeight = 256.0;
    final source = Rect.fromLTWH(
      foregroundFrameIndex * sourceWidth,
      0,
      sourceWidth,
      sourceHeight,
    );
    final tileWidth = math.max(72.0, math.min(192.0, size.y * 4));
    for (var x = 0.0; x < size.x; x += tileWidth) {
      final width = math.min(tileWidth, size.x - x);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(source.left, 0, source.width * width / tileWidth, 256),
        Rect.fromLTWH(x, 0, width, size.y),
        Paint()..filterQuality = FilterQuality.none,
      );
    }
  }

  void _drawSurfaceModule(Canvas canvas, double x) {
    final moduleHeight = math.max(0.0, math.min(size.y - 10, 14.0));
    if (moduleHeight <= 0) return;
    switch (style) {
      case PlatformSurfaceStyle.damage:
        canvas.drawRect(
          Rect.fromLTWH(x, 10, math.min(18.0, size.x - x), moduleHeight),
          Paint()..color = const Color(0x5536E1FF),
        );
        canvas.drawCircle(
          Offset(math.min(size.x - 2, x + 4), 13),
          1.8,
          Paint()..color = const Color(0xFFFFB34D),
        );
      case PlatformSurfaceStyle.temporal:
        final runeCenter = Offset(
          math.min(size.x - 5, x + 8),
          math.min(size.y - 4, 15),
        );
        canvas.drawCircle(
          runeCenter,
          5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = style.accentColor.withAlpha(150),
        );
        canvas.drawLine(
          runeCenter + const Offset(0, -4),
          runeCenter + const Offset(0, 4),
          Paint()..color = const Color(0xAAFFD35A),
        );
      case PlatformSurfaceStyle.collision:
        final right = math.min(size.x, x + 22.0);
        final bottom = math.min(size.y - 2, 22.0);
        final cell = Path()
          ..moveTo(x, 10)
          ..lineTo(right, 10)
          ..lineTo(math.max(x, right - 8), bottom)
          ..lineTo(math.min(right, x + 8), bottom)
          ..close();
        canvas.drawPath(
          cell,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = (x ~/ 32).isEven
                ? style.accentColor.withAlpha(150)
                : style.secondaryAccent.withAlpha(140),
        );
      case PlatformSurfaceStyle.optimizer:
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            10,
            math.min(16.0, size.x - x),
            math.min(4.0, moduleHeight),
          ),
          Paint()..color = style.secondaryAccent.withAlpha(150),
        );
        canvas.drawCircle(
          Offset(math.min(size.x - 3, x + 8), math.min(20, size.y - 3)),
          2.5,
          Paint()..color = const Color(0xAAFF4FD8),
        );
    }
  }
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
  int get foregroundFrameIndex => 2;

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
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 30, height: math.min(12, size.y)),
      Paint()..color = style.bodyHighlight,
    );
    canvas.drawCircle(center, 5, Paint()..color = style.secondaryAccent);
    for (final direction in <double>[-1, 1]) {
      canvas.drawLine(
        center,
        center + Offset(direction * 18, 0),
        Paint()
          ..strokeWidth = 2
          ..color = style.accentColor,
      );
    }
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
  int get foregroundFrameIndex => 2;

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

final class BreakablePlatformComponent extends PlatformSurfaceComponent {
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
  int get foregroundFrameIndex => 2;

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
        unawaited(game.audio.playPlatformBreak());
      }
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_broken) return;
    super.render(canvas);
    final crack = (_standingTime / breakDelay).clamp(0.0, 1.0);
    final crackPaint = Paint()
      ..strokeWidth = 1.5 + crack
      ..color = Color.lerp(
        const Color(0xFFFFD35A),
        style.secondaryAccent,
        crack,
      )!;
    final center = size.x * .48;
    canvas.drawLine(
      Offset(center, 4),
      Offset(center - 12, size.y - 3),
      crackPaint,
    );
    if (crack > .35) {
      canvas.drawLine(
        Offset(center - 4, size.y * .48),
        Offset(center + 15 * crack, size.y - 3),
        crackPaint,
      );
    }
    if (crack > .68) {
      canvas.drawLine(
        Offset(center + 2, 7),
        Offset(center + 22 * crack, size.y * .55),
        crackPaint,
      );
    }
  }
}

final class DamagePitComponent extends RectangleComponent {
  DamagePitComponent({
    required super.position,
    required super.size,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(paint: Paint()..color = style.bodyColor, priority: 1);

  final PlatformSurfaceStyle style;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, size.y), <Color>[
          style.secondaryAccent.withAlpha(100),
          style.bodyColor,
        ]),
    );
    final stripe = Paint()..color = style.secondaryAccent;
    for (double x = -20; x < size.x + 20; x += 20) {
      canvas.drawLine(
        Offset(x, 4),
        Offset(x + 14, 18),
        stripe..strokeWidth = 3,
      );
    }
  }
}
