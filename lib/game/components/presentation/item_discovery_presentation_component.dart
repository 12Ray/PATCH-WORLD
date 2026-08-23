import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

enum ItemRewardTier { cache, quest, boss, loadoutEvent }

/// Camera-following discovery card shown whenever a run item is collected.
final class ItemDiscoveryPresentationComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  ItemDiscoveryPresentationComponent({
    required this.result,
    required this.rewardTier,
    this.duration = 2.6,
  }) : super(size: Vector2(590, 122), anchor: Anchor.center, priority: 80);

  final RunItemAcquisitionResult result;
  final ItemRewardTier rewardTier;
  final double duration;
  double _elapsed = 0;

  RunItemId get item => result.item;

  Color get accentColor => switch (rewardTier) {
    ItemRewardTier.cache => const Color(0xFF9D8CFF),
    ItemRewardTier.quest => const Color(0xFF36E1FF),
    ItemRewardTier.boss => const Color(0xFFFFD35A),
    ItemRewardTier.loadoutEvent => const Color(0xFFFF8CEB),
  };

  String get tierLocalizationKey => result.isDuplicate
      ? 'itemDiscovery.duplicateConverted'
      : switch (rewardTier) {
          ItemRewardTier.cache => 'itemDiscovery.cache',
          ItemRewardTier.quest => 'itemDiscovery.questReward',
          ItemRewardTier.boss => 'itemDiscovery.bossReward',
          ItemRewardTier.loadoutEvent => 'itemDiscovery.loadoutEvent',
        };

  double get revealProgress => (_elapsed / .35).clamp(0, 1).toDouble();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position.setFrom(game.camera.viewfinder.position + Vector2(0, -105));
    await addAll(<Component>[
      TextComponent(
        text: game.localization.text(tierLocalizationKey),
        position: Vector2(96, 20),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: accentColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ),
      TextComponent(
        text: game.localization.text(item.localizationKey),
        position: Vector2(96, 51),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFFF7FAFF),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
      TextComponent(
        text: result.isInstalled
            ? game.localization.text(item.descriptionLocalizationKey)
            : game.localization.text(
                'itemDiscovery.duplicateIntegrity',
                parameters: <String, Object>{
                  'item': game.localization.text(item.localizationKey),
                },
              ),
        position: Vector2(96, 84),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFFBFC8DE),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ]);
  }

  @override
  void update(double dt) {
    final presentationDt = isMounted ? game.clock.realDt : dt;
    _elapsed += presentationDt;
    position.setFrom(game.camera.viewfinder.position + Vector2(0, -105));
    if (_elapsed >= duration) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final reveal = revealProgress;
    final visibleWidth = size.x * reveal;
    final body = Rect.fromLTWH(
      (size.x - visibleWidth) / 2,
      0,
      visibleWidth,
      size.y,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(10)),
      Paint()..color = const Color(0xEC111727),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accentColor.withValues(alpha: reveal),
    );
    final center = const Offset(55, 61);
    canvas.drawCircle(
      center,
      30 + math.sin(_elapsed * 5).abs() * 4,
      Paint()
        ..color = accentColor.withValues(alpha: .16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final diamond = Path()
      ..moveTo(center.dx, center.dy - 18)
      ..lineTo(center.dx + 18, center.dy)
      ..lineTo(center.dx, center.dy + 18)
      ..lineTo(center.dx - 18, center.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = accentColor);
    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF),
    );
    super.render(canvas);
  }
}
