import 'dart:ui';

import 'package:flame/components.dart';

typedef TerminalActivated = void Function(TerminalComponent terminal);

final class TerminalComponent extends RectangleComponent {
  TerminalComponent({
    required this.terminalId,
    required super.position,
    required this.onActivated,
  }) : super(
         size: Vector2(42, 52),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFF25304A),
         priority: 5,
       );

  final String terminalId;
  final TerminalActivated onActivated;
  bool _activated = false;
  bool get isActivated => _activated;

  bool tryActivate(Vector2 playerPosition) {
    if (_activated || position.distanceToSquared(playerPosition) > 56 * 56) {
      return false;
    }
    _activated = true;
    paint.color = const Color(0xFF36E1FF);
    scale.setAll(1.08);
    onActivated(this);
    return true;
  }
}
