import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

final class LegacyGlitchTerminal extends RectangleComponent {
  LegacyGlitchTerminal({required super.position, required this.onActivated})
    : super(
        size: Vector2(76, 44),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x00000000),
        priority: 6,
      );

  final void Function() onActivated;
  bool _enabled = false;
  bool _coolingDown = false;
  double _time = 0;
  bool get isEnabled => _enabled && !_coolingDown;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: 'L',
        position: size / 2,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFF4F7FF),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void enable() {
    _enabled = true;
    _coolingDown = false;
  }

  void disableForCooldown() {
    _enabled = false;
    _coolingDown = true;
  }

  @override
  void update(double dt) {
    _time += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(width / 2, height / 2);
    final pulse = 1 + math.sin(_time * 5) * 0.12;
    final activeColor = isEnabled
        ? const Color(0xFF36E1FF)
        : _coolingDown
        ? const Color(0xFF7E345F)
        : const Color(0xFF41506B);
    canvas.drawCircle(
      center,
      25 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isEnabled ? 3 : 1.5
        ..color = activeColor.withValues(alpha: 0.7),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 38, height: 38),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = activeColor,
    );
    for (final direction in <Offset>[
      const Offset(0, -1),
      const Offset(1, 0),
      const Offset(0, 1),
      const Offset(-1, 0),
    ]) {
      canvas.drawLine(
        center + direction * 22,
        center + direction * 31,
        Paint()
          ..strokeWidth = 3
          ..color = activeColor,
      );
    }
  }

  bool tryActivate(Vector2 playerPosition) {
    if (!isEnabled || position.distanceToSquared(playerPosition) > 64 * 64) {
      return false;
    }
    disableForCooldown();
    onActivated();
    return true;
  }
}
