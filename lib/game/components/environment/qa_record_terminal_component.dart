import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class QaRecordTerminalComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  QaRecordTerminalComponent({
    required super.position,
    required this.recordId,
    required this.onCollected,
    this.labelLocalizationKey = 'quest.qaRecord',
  }) : super(size: Vector2(52, 72), anchor: Anchor.bottomCenter, priority: 16);

  final int recordId;
  final void Function(int recordId) onCollected;
  final String labelLocalizationKey;
  double _clock = 0;
  bool _collected = false;

  bool tryCollect(PlayerComponent player) {
    if (_collected || player.position.distanceTo(position) > 76) return false;
    _collected = true;
    onCollected(recordId);
    removeFromParent();
    return true;
  }

  @override
  void update(double dt) {
    _clock += game.clock.simulationDt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final pulse = ((math.sin(_clock * 5) + 1) * .5 * 80).round();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 12, 36, 60),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF263055),
    );
    canvas.drawRect(
      const Rect.fromLTWH(14, 19, 24, 35),
      Paint()..color = Color.fromARGB(150 + pulse, 54, 225, 255),
    );
    for (var line = 0; line < 3; line += 1) {
      canvas.drawRect(
        Rect.fromLTWH(18, 25 + line * 8, 16 - line * 2, 2),
        Paint()..color = const Color(0xFFF3F7FF),
      );
    }
    super.render(canvas);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text:
            '${game.localization.text(labelLocalizationKey)} ${recordId + 1}/3  [L]',
        position: Vector2(size.x / 2, 2),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFF9DEFFF),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
