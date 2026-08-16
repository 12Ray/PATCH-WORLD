import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class TemporalStormComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  TemporalStormComponent({Vector2? worldSize})
    : super(
        size:
            worldSize ??
            Vector2(PatchWorldGame.logicalWidth, PatchWorldGame.logicalHeight),
        priority: 6,
      );

  double _phase = 0;

  @override
  void update(double dt) {
    if (game.survivalRun.elapsedSeconds >= 300) {
      _phase += game.clock.simulationDt;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (game.survivalRun.elapsedSeconds < 300) return;
    final pulse = 0.5 + 0.5 * math.sin(_phase * math.pi / 2);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 + pulse * 4
      ..color = Color.fromRGBO(255, 79, 216, 0.20 + pulse * 0.22);
    canvas.drawRect(Rect.fromLTWH(27, 27, size.x - 54, size.y - 54), border);
    final scan = Paint()
      ..strokeWidth = 2
      ..color = Color.fromRGBO(54, 225, 255, 0.05 + pulse * 0.07);
    final offset = (_phase * 70) % 48;
    for (var x = -size.y + offset; x < size.x; x += 48) {
      canvas.drawLine(Offset(x, 24), Offset(x + size.y, size.y - 24), scan);
    }
  }
}
