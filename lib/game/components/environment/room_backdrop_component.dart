import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

enum RoomBackdropStyle { damage, temporal, collision, optimizer, survival }

/// Code-native environment art that makes each rule room visually distinct.
final class RoomBackdropComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  RoomBackdropComponent(this.style)
    : super(
        size: Vector2(
          PatchWorldGame.logicalWidth,
          PatchWorldGame.logicalHeight,
        ),
        priority: -100,
      );

  final RoomBackdropStyle style;
  double _time = 0;

  @override
  void update(double dt) {
    _time += style == RoomBackdropStyle.temporal ? game.clock.simulationDt : dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF090F1D));
    _drawPanels(canvas);
    switch (style) {
      case RoomBackdropStyle.damage:
        _drawDamageLab(canvas);
      case RoomBackdropStyle.temporal:
        _drawTemporalHall(canvas);
      case RoomBackdropStyle.collision:
        _drawCollisionArchive(canvas);
      case RoomBackdropStyle.optimizer:
        _drawOptimizerCore(canvas);
      case RoomBackdropStyle.survival:
        _drawSurvivalArena(canvas);
    }
    canvas.drawRect(
      const Rect.fromLTWH(24, 24, 912, 492),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x6636E1FF),
    );
  }

  void _drawPanels(Canvas canvas) {
    const cell = 48.0;
    for (var row = 0; row < 12; row += 1) {
      for (var col = 0; col < 20; col += 1) {
        final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);
        canvas.drawRect(
          rect,
          Paint()
            ..color = (row + col).isEven
                ? const Color(0xFF0D1728)
                : const Color(0xFF0A1322),
        );
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0x182C5473),
        );
      }
    }
  }

  void _drawDamageLab(Canvas canvas) {
    final pulse = 0.35 + math.sin(_time * 2.8) * 0.12;
    _drawConduit(
      canvas,
      const Offset(90, 180),
      const Offset(870, 180),
      const Color(0xFF36E1FF),
      pulse,
    );
    _drawConduit(
      canvas,
      const Offset(90, 360),
      const Offset(870, 360),
      const Color(0xFFFF4FD8),
      pulse,
    );
    for (final x in <double>[260, 480, 700]) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, 270), width: 92, height: 92),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x332CF2C8),
      );
    }
  }

  void _drawTemporalHall(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final frozen = game.clock.isSimulationFrozen;
    for (var i = 0; i < 4; i += 1) {
      final inset = 58.0 + i * 42;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset, 82 + i * 14, 960 - inset * 2, 376 - i * 28),
          Radius.circular(36 + i * 8),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 3 : 1.3
          ..color = frozen
              ? Color.fromRGBO(54, 225, 255, 0.18 + i * 0.04)
              : Color.fromRGBO(255, 79, 216, 0.12 + i * 0.04),
      );
    }
    for (var index = 0; index < 12; index += 1) {
      final angle = index * math.pi / 6 + _time * 0.7;
      final inner = 96.0 + (index.isEven ? 18 : 0);
      final outer = 188.0 + (index % 3) * 24;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        Paint()
          ..strokeWidth = frozen ? 2.2 : 1.2
          ..color = frozen ? const Color(0x6636E1FF) : const Color(0x44FF4FD8),
      );
    }
    canvas.drawCircle(
      center,
      42 + math.sin(_time * 2.2) * 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = frozen ? 4 : 2
        ..color = frozen ? const Color(0xAA36E1FF) : const Color(0x88FF4FD8),
    );
  }

  void _drawCollisionArchive(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    for (var i = 0; i < 5; i += 1) {
      canvas.drawCircle(
        center,
        72 + i * 34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i.isEven ? 2 : 1
          ..color = i.isEven
              ? const Color(0x4436E1FF)
              : const Color(0x33FF4FD8),
      );
    }
    _drawConduit(
      canvas,
      const Offset(80, 270),
      const Offset(880, 270),
      const Color(0xFFFF4FD8),
      0.32,
    );
  }

  void _drawOptimizerCore(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    for (var i = 0; i < 7; i += 1) {
      canvas.drawCircle(
        center,
        72 + i * 34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i % 3 == 0 ? 3 : 1
          ..color = Color.fromRGBO(255, 79, 216, 0.12 + i * 0.025),
      );
    }
    _drawConduit(
      canvas,
      const Offset(60, 270),
      const Offset(900, 270),
      const Color(0xFFFF4FD8),
      0.45,
    );
    _drawConduit(
      canvas,
      const Offset(480, 52),
      const Offset(480, 488),
      const Color(0xFFFF4FD8),
      0.45,
    );
  }

  void _drawSurvivalArena(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    for (var index = 0; index < 12; index += 1) {
      final angle = index * math.pi / 6 + _time * 0.08;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * 90,
        center + Offset(math.cos(angle), math.sin(angle)) * 420,
        Paint()
          ..strokeWidth = index.isEven ? 2 : 1
          ..color = index.isEven
              ? const Color(0x3336E1FF)
              : const Color(0x2EFF4FD8),
      );
    }
    canvas.drawCircle(
      center,
      88 + math.sin(_time * 1.8) * 8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x6636E1FF),
    );
  }

  void _drawConduit(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double opacity,
  ) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeWidth = 2
        ..color = color.withValues(alpha: opacity),
    );
  }
}
