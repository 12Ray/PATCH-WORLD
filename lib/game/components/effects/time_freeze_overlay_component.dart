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
  void update(double dt) {
    position.setValues(
      game.camera.viewfinder.position.x - size.x / 2,
      game.camera.viewfinder.position.y - size.y / 2,
    );
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (!game.clock.isSimulationFrozen ||
        game.currentRoom != RoomId.temporalHall) {
      return;
    }
    _linePaint.color = game.settings.value.flash == FlashSetting.reduced
        ? const Color(0x0A36E1FF)
        : const Color(0x2236E1FF);
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = game.settings.value.flash == FlashSetting.reduced
            ? const Color(0x0800C8FF)
            : const Color(0x1400C8FF),
    );
    for (double y = 0; y < height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(width, y), _linePaint);
    }
    final center = Offset(width / 2, height / 2);
    canvas.drawCircle(
      center,
      32,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x5536E1FF),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(-7, 0), width: 5, height: 18),
      Paint()..color = const Color(0x8836E1FF),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(7, 0), width: 5, height: 18),
      Paint()..color = const Color(0x8836E1FF),
    );
  }
}
