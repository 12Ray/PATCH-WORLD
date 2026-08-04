import 'dart:ui';

import 'package:flame/components.dart';

final class LegacyGlitchTerminal extends RectangleComponent {
  LegacyGlitchTerminal({required super.position, required this.onActivated})
    : super(
        size: Vector2(76, 44),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFF25304A),
        priority: 6,
      );

  final void Function() onActivated;
  bool _enabled = false;
  bool _coolingDown = false;
  bool get isEnabled => _enabled && !_coolingDown;

  void enable() {
    _enabled = true;
    _coolingDown = false;
    paint.color = const Color(0xFFFF4FD8);
  }

  void disableForCooldown() {
    _enabled = false;
    _coolingDown = true;
    paint.color = const Color(0xFF5A294F);
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
