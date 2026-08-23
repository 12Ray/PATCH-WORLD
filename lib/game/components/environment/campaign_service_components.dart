import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/presentation/item_discovery_presentation_component.dart';
import 'package:patch_world/game/items/campaign_loadout_reward_catalog.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class CampaignRepairStationComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  CampaignRepairStationComponent({
    required super.position,
    required this.onUsed,
    this.used = false,
    this.accentColor = const Color(0xFF45F3A6),
  }) : super(size: Vector2(88, 74), anchor: Anchor.bottomCenter, priority: 18);

  final VoidCallback onUsed;
  final Color accentColor;
  bool used;
  double _clock = 0;

  bool tryUse(PlayerComponent player) {
    if (player.position.distanceTo(position) > 92) return false;
    if (used) return true;
    used = true;
    player.restoreIntegrity(player.maxIntegrity);
    onUsed();
    game.publishUiSnapshot(force: true);
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: '${game.localization.text('interaction.repairStation')}  [L]',
        position: Vector2(size.x / 2, -3),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFFF3F7FF),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    _clock += game.clock.simulationDt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final color = used ? const Color(0xFF56627A) : accentColor;
    final pulse = .5 + math.sin(_clock * 2.6) * .5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 30, size.x - 10, 38),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xEE141B35),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.x / 2, 42), width: 26, height: 8),
      Paint()..color = color,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.x / 2, 42), width: 8, height: 26),
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(size.x / 2, 42),
      18 + pulse * 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color.withValues(alpha: .35),
    );
    super.render(canvas);
  }
}

/// A one-time, loadout-reactive event. The starting weapon decides which
/// synergy module materializes, so every weapon gets a useful exploration
/// reward without making any route mandatory.
final class LoadoutEventTerminalComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  LoadoutEventTerminalComponent({
    required super.position,
    required this.eventId,
    required this.onResolved,
    this.resolved = false,
    this.accentColor = const Color(0xFFFFD35A),
  }) : super(size: Vector2(94, 80), anchor: Anchor.bottomCenter, priority: 18);

  final CampaignLoadoutEventId eventId;
  final VoidCallback onResolved;
  final Color accentColor;
  bool resolved;
  double _clock = 0;

  bool tryResolve(PlayerComponent player) {
    if (player.position.distanceTo(position) > 94) return false;
    if (resolved) return true;
    resolved = true;
    final item = CampaignLoadoutRewardCatalog.rewardFor(
      eventId,
      player.selectedWeapon,
    );
    final result = game.runItems.acquire(item);
    player.restoreIntegrity(1);
    onResolved();
    final owner = parent;
    if (owner != null) {
      owner.add(
        ItemDiscoveryPresentationComponent(
          result: result,
          rewardTier: ItemRewardTier.loadoutEvent,
        ),
      );
    }
    unawaited(game.audio.playHeal());
    game.publishUiSnapshot(force: true);
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: '${game.localization.text('interaction.resolveEvent')}  [L]',
        position: Vector2(size.x / 2, -3),
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
  void update(double dt) {
    _clock += game.clock.simulationDt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final color = resolved ? const Color(0xFF56627A) : accentColor;
    final bob = math.sin(_clock * 2.8) * 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 32, size.x - 16, 42),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xEE141B35),
    );
    final center = Offset(size.x / 2, 34 + bob);
    final diamond = Path()
      ..moveTo(center.dx, center.dy - 12)
      ..lineTo(center.dx + 12, center.dy)
      ..lineTo(center.dx, center.dy + 12)
      ..lineTo(center.dx - 12, center.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = color);
    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFF4F7FF),
    );
    super.render(canvas);
  }
}
