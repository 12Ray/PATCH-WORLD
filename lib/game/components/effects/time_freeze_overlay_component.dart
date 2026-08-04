import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/game_settings.dart';
import 'package:patch_world/game/rules/rule_context.dart';

final class TimeFreezeOverlayComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  TimeFreezeOverlayComponent()
    : super(
        size: Vector2(
          PatchWorldGame.logicalWidth,
          PatchWorldGame.logicalHeight,
        ),
        priority: 1000,
      );

  final Paint _linePaint = Paint()
    ..color = const Color(0x2236E1FF)
    ..strokeWidth = 1;

  @override
  void render(Canvas canvas) {
    if (!game.clock.isSimulationFrozen ||
        game.currentRoom != RoomId.temporalHall) {
      return;
    }
    _linePaint.color = game.settings.value.flash == FlashSetting.reduced
        ? const Color(0x0A36E1FF)
        : const Color(0x2236E1FF);
    for (double y = 0; y < height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(width, y), _linePaint);
    }
  }
}
