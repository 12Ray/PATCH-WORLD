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
    this.isUnlockedResolver,
    this.isCompletedResolver,
    this.lockedLabelLocalizationKeyResolver,
    this.onLockedInteract,
  }) : super(size: Vector2(72, 104), anchor: Anchor.bottomCenter, priority: 16);

  final String labelLocalizationKey;
  final bool Function() onInteract;
  final Color accentColor;
  final bool Function()? isUnlockedResolver;
  final bool Function()? isCompletedResolver;
  final String Function()? lockedLabelLocalizationKeyResolver;
  final VoidCallback? onLockedInteract;
  double _clock = 0;
  bool _activated = false;
  bool _labelVisible = false;
  late final TextComponent _label;

  bool get isUnlocked => isUnlockedResolver?.call() ?? true;
  bool get isCompleted => isCompletedResolver?.call() ?? false;

  String get currentLabelLocalizationKey => isUnlocked
      ? labelLocalizationKey
      : lockedLabelLocalizationKeyResolver?.call() ?? 'interaction.routeLocked';

  bool isNear(PlayerComponent player) =>
      player.position.distanceTo(position - Vector2(0, 36)) <= 92;

  bool tryEnter(PlayerComponent player) {
    if (_activated || !isNear(player)) return false;
    if (!isUnlocked) {
      onLockedInteract?.call();
      return true;
    }
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
    if (_labelVisible != labelVisible || labelVisible) {
      _labelVisible = labelVisible;
      if (!labelVisible) {
        _label.text = '';
      } else {
        final completion = isCompleted
            ? '  ✓ ${game.localization.text('interaction.regionComplete')}'
            : '';
        _label.text =
            '${game.localization.text(currentLabelLocalizationKey)}$completion  [L]';
      }
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final pulse = .58 + math.sin(_clock * 3.4).abs() * .32;
    final renderColor = isCompleted
        ? const Color(0xFF45F3A6)
        : isUnlocked
        ? accentColor
        : const Color(0xFFFF8A5B);
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 8, size.x - 8, size.y - 8),
      const Radius.circular(10),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xFF141D38));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = renderColor.withValues(alpha: pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRect(
      Rect.fromLTWH(18, 24, size.x - 36, size.y - 42),
      Paint()..color = renderColor.withValues(alpha: .14 + pulse * .18),
    );
    for (var index = 0; index < 3; index += 1) {
      final y = 36.0 + index * 16;
      canvas.drawLine(
        Offset(25, y),
        Offset(size.x - 25, y),
        Paint()
          ..color = renderColor.withValues(alpha: pulse)
          ..strokeWidth = 2,
      );
    }
    if (isCompleted) {
      const badgeCenter = Offset(61, 17);
      canvas.drawCircle(
        badgeCenter,
        10,
        Paint()..color = const Color(0xFF45F3A6),
      );
      final check = Path()
        ..moveTo(badgeCenter.dx - 5, badgeCenter.dy)
        ..lineTo(badgeCenter.dx - 1, badgeCenter.dy + 4)
        ..lineTo(badgeCenter.dx + 6, badgeCenter.dy - 5);
      canvas.drawPath(
        check,
        Paint()
          ..color = const Color(0xFF071A18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    super.render(canvas);
  }
}
