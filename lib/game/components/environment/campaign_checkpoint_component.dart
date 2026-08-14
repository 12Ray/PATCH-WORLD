import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class CampaignCheckpointComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  CampaignCheckpointComponent({
    required super.position,
    required this.onActivated,
    this.isActive = false,
  }) : super(size: Vector2(92, 62), anchor: Anchor.bottomCenter, priority: 17);

  final VoidCallback onActivated;
  bool isActive;

  bool tryActivate(PlayerComponent player) {
    if (player.position.distanceTo(position) > 86) return false;
    isActive = true;
    onActivated();
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text:
            '${game.localization.text('interaction.activateCheckpoint')}  [L]',
        position: Vector2(size.x / 2, -2),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFFFFE39A),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final glow = isActive ? const Color(0xFF45F3A6) : const Color(0xFFFFD35A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 30, size.x - 8, 26),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFF25304A),
    );
    canvas.drawRect(
      Rect.fromLTWH(16, 20, size.x - 32, 18),
      Paint()..color = glow.withValues(alpha: .45),
    );
    canvas.drawCircle(Offset(size.x / 2, 18), 7, Paint()..color = glow);
    super.render(canvas);
  }
}
