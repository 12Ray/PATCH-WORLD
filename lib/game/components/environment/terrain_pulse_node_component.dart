import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

/// A persistent metroidvania switch. It can be used only after the Collision
/// Archive core grants Terrain Pulse, and rebuilds the same optional bridge
/// when a previously visited room is loaded again.
final class TerrainPulseNodeComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  TerrainPulseNodeComponent({
    required super.position,
    required this.nodeId,
    required this.onActivated,
    this.accentColor = const Color(0xFF2CF2C8),
  }) : super(size: Vector2(74, 70), anchor: Anchor.bottomCenter, priority: 18);

  final String nodeId;
  final VoidCallback onActivated;
  final Color accentColor;
  bool _activated = false;
  double _clock = 0;

  bool get isActivated => _activated;
  bool get isUnlocked => game.campaignExploration.hasTraversalAbility(
    CampaignTraversalAbility.terrainPulse,
  );

  bool tryActivate(PlayerComponent player) {
    if (player.position.distanceTo(position) > 88) return false;
    if (_activated || !isUnlocked) return true;
    _activated = true;
    game.campaignExploration.activateTerrainNode(nodeId);
    onActivated();
    game.publishUiSnapshot(force: true);
    return true;
  }

  void restoreActivated() {
    if (_activated) return;
    _activated = true;
    onActivated();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: '${game.localization.text('interaction.terrainPulse')}  [L]',
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
    final unlocked = isUnlocked;
    final color = _activated
        ? const Color(0xFFFFD35A)
        : unlocked
        ? accentColor
        : const Color(0xFF56627A);
    final pulse = .5 + math.sin(_clock * 3) * .5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 28, size.x - 16, 36),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xEE141B35),
    );
    canvas.drawCircle(
      Offset(size.x / 2, 28),
      12 + pulse * 2,
      Paint()..color = color.withValues(alpha: .32),
    );
    canvas.drawCircle(Offset(size.x / 2, 28), 7, Paint()..color = color);
    canvas.drawLine(
      Offset(size.x / 2 - 14, 50),
      Offset(size.x / 2 + 14, 50),
      Paint()
        ..strokeWidth = 3
        ..color = color,
    );
    super.render(canvas);
  }
}

/// A projected optional route whose collision and visual state change
/// together, avoiding the backdrop/collision mismatch of invisible floors.
final class TerrainPulseBridgeComponent extends PlatformSurfaceComponent {
  TerrainPulseBridgeComponent({
    required super.position,
    required super.size,
    required super.style,
  });

  bool _activated = false;
  bool get isActivated => _activated;

  void activate() => _activated = true;

  @override
  bool get isSolid => _activated && super.isSolid;

  @override
  void render(Canvas canvas) {
    if (_activated) {
      super.render(canvas);
      return;
    }
    final half = size.x * .38;
    for (final rect in <Rect>[
      Rect.fromLTWH(0, 2, half, math.max(4, size.y - 4)),
      Rect.fromLTWH(size.x - half, 2, half, math.max(4, size.y - 4)),
    ]) {
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = style.accentColor.withValues(alpha: .55),
      );
    }
  }
}
