import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';

final class PatchWorld extends World {
  static final Vector2 _logicalSize = Vector2(960, 540);
  static final Vector2 _topLeft = Vector2(-480, -270);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    addAll([
      RectangleComponent(
        position: _topLeft,
        size: _logicalSize,
        paint: Paint()..color = const Color(0xFF080B14),
      ),
      _GridBackdrop(position: _topLeft, size: _logicalSize),
      RectangleComponent(
        position: Vector2(-420, -206),
        size: Vector2(840, 348),
        paint: Paint()
          ..color = const Color(0xFF0D1420)
          ..style = PaintingStyle.fill,
      ),
      RectangleComponent(
        position: Vector2(-420, -206),
        size: Vector2(840, 348),
        paint: Paint()
          ..color = const Color(0xFF45F3A6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      ),
      TextComponent(
        text: 'PATCH//WORLD',
        position: Vector2(-388, -178),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFE9FFF5),
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ),
      TextComponent(
        text: 'THE LAST RULE CHOSEN BY A HUMAN',
        position: Vector2(-384, -122),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF45F3A6),
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ),
      _StatusPanel(position: Vector2(-384, -62)),
      TextComponent(
        text: 'P0 // WEB BOOTSTRAP ONLINE',
        position: Vector2(-388, 105),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      TextComponent(
        text: '960 x 540  |  FLUTTER 3.44  |  FLAME 1.38',
        position: Vector2(-388, 162),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF8190A8),
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
      ),
    ]);
  }
}

final class _StatusPanel extends PositionComponent {
  _StatusPanel({required super.position}) : super(size: Vector2(768, 128));

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final panelPaint = Paint()..color = const Color(0xFF111C2A);
    final linePaint = Paint()
      ..color = const Color(0xFF24384A)
      ..strokeWidth = 1;
    canvas.drawRect(size.toRect(), panelPaint);
    canvas.drawLine(const Offset(0, 64), const Offset(768, 64), linePaint);

    _drawLabel(canvas, 'CURRENT RULE', const Offset(20, 16));
    _drawValue(canvas, 'DAMAGE_SIGN_INVERTED', const Offset(196, 16));
    _drawLabel(canvas, 'NEXT GATE', const Offset(20, 80));
    _drawValue(canvas, 'PLAYER + BASE COMBAT', const Offset(196, 80));
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    TextPaint(
      style: const TextStyle(
        color: Color(0xFF8190A8),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    ).render(canvas, text, Vector2(offset.dx, offset.dy));
  }

  void _drawValue(Canvas canvas, String text, Offset offset) {
    TextPaint(
      style: const TextStyle(
        color: Color(0xFFE9FFF5),
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ).render(canvas, text, Vector2(offset.dx, offset.dy));
  }
}

final class _GridBackdrop extends PositionComponent {
  _GridBackdrop({required super.position, required super.size});

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()
      ..color = const Color(0x122F6E5B)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.x; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), paint);
    }
    for (double y = 0; y <= size.y; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), paint);
    }
  }
}
