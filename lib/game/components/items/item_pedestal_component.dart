import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class ItemPedestalComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  ItemPedestalComponent({
    required super.position,
    required this.item,
    required this.onCollected,
  }) : super(size: Vector2(82, 78), anchor: Anchor.bottomCenter, priority: 18);

  final RunItemId item;
  final void Function(RunItemId item) onCollected;
  double _clock = 0;
  bool _collected = false;

  bool tryCollect(PlayerComponent player) {
    if (_collected || player.position.distanceTo(position) > 90) return false;
    _collected = true;
    onCollected(item);
    game.runItems.acquire(item);
    game.world.player.restoreIntegrity(1);
    game.publishUiSnapshot(force: true);
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
    final pulse = .5 + math.sin(_clock * 3.5) * .5;
    const cyan = Color(0xFF36E1FF);
    const gold = Color(0xFFFFD35A);
    final center = Offset(size.x / 2, 26 + math.sin(_clock * 2.5) * 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.x / 2, 69), width: 68, height: 16),
      Paint()..color = const Color(0xAA141B35),
    );
    canvas.drawRect(
      Rect.fromLTWH(15, 54, 52, 15),
      Paint()..color = const Color(0xFF29345D),
    );
    canvas.drawCircle(
      center,
      20 + pulse * 3,
      Paint()
        ..color = cyan.withAlpha(38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final diamond = Path()
      ..moveTo(center.dx, center.dy - 13)
      ..lineTo(center.dx + 13, center.dy)
      ..lineTo(center.dx, center.dy + 13)
      ..lineTo(center.dx - 13, center.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()..color = item == RunItemId.conduitHeart ? cyan : gold,
    );
    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF),
    );
    super.render(canvas);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: '${game.localization.text(item.localizationKey)}  [L]',
        position: Vector2(size.x / 2, -6),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFF3F7FF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}
