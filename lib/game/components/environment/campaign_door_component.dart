import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class CampaignDoorComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  CampaignDoorComponent({
    required super.position,
    required this.labelLocalizationKey,
    required this.onInteract,
    this.accentColor = const Color(0xFF36E1FF),
  }) : super(size: Vector2(72, 104), anchor: Anchor.bottomCenter, priority: 16);

  final String labelLocalizationKey;
  final bool Function() onInteract;
  final Color accentColor;
  double _clock = 0;
  bool _activated = false;
  bool _labelVisible = false;
  late final TextComponent _label;

  bool isNear(PlayerComponent player) =>
      player.position.distanceTo(position - Vector2(0, 36)) <= 92;

  bool tryEnter(PlayerComponent player) {
    if (_activated || !isNear(player)) return false;
    _activated = onInteract();
    return _activated;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _label = TextComponent(
      text: '',
      position: Vector2(size.x / 2, -4),
      anchor: Anchor.bottomCenter,
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'PatchWorldCJK',
          color: accentColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    );
    await add(_label);
  }

  @override
  void update(double dt) {
    _clock += game.clock.realDt;
    final labelVisible =
        game.world.player.position.distanceTo(position - Vector2(0, 36)) <= 140;
    if (_labelVisible != labelVisible) {
      _labelVisible = labelVisible;
      _label.text = labelVisible
          ? '${game.localization.text(labelLocalizationKey)}  [L]'
          : '';
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final pulse = .58 + math.sin(_clock * 3.4).abs() * .32;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 8, size.x - 8, size.y - 8),
      const Radius.circular(10),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xFF141D38));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = accentColor.withValues(alpha: pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRect(
      Rect.fromLTWH(18, 24, size.x - 36, size.y - 42),
      Paint()..color = accentColor.withValues(alpha: .14 + pulse * .18),
    );
    for (var index = 0; index < 3; index += 1) {
      final y = 36.0 + index * 16;
      canvas.drawLine(
        Offset(25, y),
        Offset(size.x - 25, y),
        Paint()
          ..color = accentColor.withValues(alpha: pulse)
          ..strokeWidth = 2,
      );
    }
    super.render(canvas);
  }
}
