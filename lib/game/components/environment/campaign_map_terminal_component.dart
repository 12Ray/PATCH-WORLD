import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class CampaignMapTerminalComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  CampaignMapTerminalComponent({
    required super.position,
    required this.onInteract,
  }) : super(size: Vector2(68, 88), anchor: Anchor.bottomCenter, priority: 17);

  final VoidCallback onInteract;
  double _clock = 0;

  bool tryUse(PlayerComponent player) {
    if (player.position.distanceTo(position) > 84) return false;
    onInteract();
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: '${game.localization.text('interaction.openMap')}  [L]',
        position: Vector2(size.x / 2, -2),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFF9DEFFF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    _clock += game.clock.realDt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final pulse = .55 + math.sin(_clock * 3).abs() * .35;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 8, size.x - 10, size.y - 8),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF202B50),
    );
    canvas.drawRect(
      Rect.fromLTWH(14, 18, size.x - 28, 42),
      Paint()..color = const Color(0xFF36E1FF).withValues(alpha: pulse * .45),
    );
    final routePaint = Paint()
      ..color = const Color(0xFF9DEFFF).withValues(alpha: pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(21, 48), const Offset(34, 29), routePaint);
    canvas.drawLine(const Offset(34, 29), const Offset(48, 44), routePaint);
    for (final point in const <Offset>[
      Offset(21, 48),
      Offset(34, 29),
      Offset(48, 44),
    ]) {
      canvas.drawCircle(point, 3, routePaint);
    }
    super.render(canvas);
  }
}
