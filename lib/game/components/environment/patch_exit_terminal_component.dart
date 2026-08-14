import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class PatchExitTerminalComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  PatchExitTerminalComponent({
    required super.position,
    required this.accentColor,
  }) : super(size: Vector2(64, 84), anchor: Anchor.bottomCenter, priority: 16);

  final Color accentColor;
  double _clock = 0;

  bool isNear(PlayerComponent player) =>
      player.position.distanceTo(position) <= 82;

  @override
  void update(double dt) {
    _clock += game.clock.simulationDt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final glow = 120 + (math.sin(_clock * 4).abs() * 100).round();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, 48, 76),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFF202B50),
    );
    canvas.drawRect(
      const Rect.fromLTWH(16, 18, 32, 42),
      Paint()..color = accentColor.withAlpha(glow),
    );
    super.render(canvas);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: '${game.localization.text('interaction.applyPatch')}  [L]',
        position: Vector2(size.x / 2, 0),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: accentColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
