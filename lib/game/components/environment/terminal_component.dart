import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

typedef TerminalActivated = void Function(TerminalComponent terminal);

final class TerminalComponent extends RectangleComponent {
  TerminalComponent({
    required this.terminalId,
    required super.position,
    required this.onActivated,
    this.requiredChargeSeconds = 0,
  }) : super(
         size: Vector2(42, 52),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFF25304A),
         priority: 5,
       );

  final String terminalId;
  final TerminalActivated onActivated;
  final double requiredChargeSeconds;
  bool _activated = false;
  double _chargeSeconds = 0;
  TextComponent? _prompt;
  bool get isActivated => _activated;
  bool get isReady =>
      requiredChargeSeconds <= 0 || _chargeSeconds >= requiredChargeSeconds;
  double get chargeProgress => requiredChargeSeconds <= 0
      ? 1
      : (_chargeSeconds / requiredChargeSeconds).clamp(0, 1).toDouble();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final prompt = TextComponent(
      text: isReady ? 'E' : '…',
      position: size / 2,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFF4F7FF),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    _prompt = prompt;
    await add(prompt);
  }

  void updateCharge({
    required Vector2 playerPosition,
    required double dt,
    required bool isMoving,
  }) {
    if (_activated || isReady || !isMoving || dt <= 0) return;
    if (position.distanceToSquared(playerPosition) > 72 * 72) return;
    _chargeSeconds = math.min(requiredChargeSeconds, _chargeSeconds + dt);
    paint.color = Color.lerp(
      const Color(0xFF25304A),
      const Color(0xFF36E1FF),
      chargeProgress * 0.72,
    )!;
    if (isReady) {
      _prompt?.text = 'E';
      scale.setAll(1.06);
    }
  }

  bool tryActivate(Vector2 playerPosition) {
    if (_activated ||
        !isReady ||
        position.distanceToSquared(playerPosition) > 56 * 56) {
      return false;
    }
    _activated = true;
    paint.color = const Color(0xFF36E1FF);
    scale.setAll(1.08);
    onActivated(this);
    return true;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (requiredChargeSeconds <= 0 || _activated) return;
    final ring = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: width + 16,
      height: height + 16,
    );
    canvas.drawArc(
      ring,
      -math.pi / 2,
      math.pi * 2 * chargeProgress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = isReady ? const Color(0xFF36E1FF) : const Color(0xFFFF4FD8),
    );
  }
}
