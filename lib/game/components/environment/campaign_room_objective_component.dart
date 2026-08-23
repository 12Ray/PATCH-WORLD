import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

enum CampaignRoomObjectiveVisualStyle {
  clockAnchor,
  echoRelay,
  rewindLock,
  pressureValve,
  phaseShard,
  polarityCoil,
}

enum CampaignRoomObjectiveInteractionResult {
  activated,
  completed,
  reset,
  rejected,
  alreadyActivated,
}

final class CampaignRoomObjectiveComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  CampaignRoomObjectiveComponent({
    required super.position,
    required this.nodeIndex,
    required this.visualStyle,
    required this.labelLocalizationKey,
    required this.accentColor,
    required this.onInteract,
    this.activationOrdinal,
    this.activated = false,
  }) : super(size: Vector2(82, 78), anchor: Anchor.bottomCenter, priority: 19);

  final int nodeIndex;
  final int? activationOrdinal;
  final CampaignRoomObjectiveVisualStyle visualStyle;
  final String labelLocalizationKey;
  final Color accentColor;
  final CampaignRoomObjectiveInteractionResult Function(int nodeIndex)
  onInteract;

  bool activated;
  double _clock = 0;
  double _rejectionRemaining = 0;
  bool _labelVisible = false;
  late final TextComponent _label;

  bool get isRejected => _rejectionRemaining > 0;

  String get currentLabelLocalizationKey =>
      activated ? 'interaction.objectiveNodeSynced' : labelLocalizationKey;

  bool isNear(PlayerComponent player) =>
      player.position.distanceTo(position) <= 92;

  bool tryActivate(PlayerComponent player) {
    if (activated || !isNear(player)) return false;
    final result = onInteract(nodeIndex);
    if (result == CampaignRoomObjectiveInteractionResult.reset ||
        result == CampaignRoomObjectiveInteractionResult.rejected) {
      _rejectionRemaining = .7;
    }
    return true;
  }

  void syncActivated(bool value) {
    activated = value;
    if (value) _rejectionRemaining = 0;
  }

  void markRejected() {
    _rejectionRemaining = .7;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _label = TextComponent(
      text: '',
      position: Vector2(size.x / 2, -3),
      anchor: Anchor.bottomCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'PatchWorldCJK',
          color: Color(0xFFF3F7FF),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .35,
        ),
      ),
    );
    await add(_label);
  }

  @override
  void update(double dt) {
    _clock += game.clock.simulationDt;
    _rejectionRemaining = math.max(0, _rejectionRemaining - game.clock.realDt);
    final labelVisible = game.world.player.position.distanceTo(position) <= 142;
    if (_labelVisible != labelVisible || labelVisible) {
      _labelVisible = labelVisible;
      final ordinal = activationOrdinal == null ? '' : ' ${activationOrdinal!}';
      final actionHint = activated ? '' : '  [L]';
      _label.text = labelVisible
          ? '${game.localization.text(currentLabelLocalizationKey)}$ordinal$actionHint'
          : '';
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final pulse = .5 + math.sin(_clock * 3.2 + nodeIndex) * .5;
    final stateColor = isRejected
        ? const Color(0xFFFF5A7A)
        : activated
        ? const Color(0xFF45F3A6)
        : accentColor;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 20, size.x - 10, size.y - 22),
      const Radius.circular(9),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xEE11182E));
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = activated ? 3 : 2
        ..color = stateColor.withValues(alpha: .62 + pulse * .3),
    );

    final center = Offset(size.x / 2, 47);
    switch (visualStyle) {
      case CampaignRoomObjectiveVisualStyle.clockAnchor:
        _drawClock(canvas, center, stateColor);
      case CampaignRoomObjectiveVisualStyle.echoRelay:
        _drawEcho(canvas, center, stateColor);
      case CampaignRoomObjectiveVisualStyle.rewindLock:
        _drawRewind(canvas, center, stateColor);
      case CampaignRoomObjectiveVisualStyle.pressureValve:
        _drawValve(canvas, center, stateColor);
      case CampaignRoomObjectiveVisualStyle.phaseShard:
        _drawShard(canvas, center, stateColor);
      case CampaignRoomObjectiveVisualStyle.polarityCoil:
        _drawCoil(canvas, center, stateColor);
    }
    super.render(canvas);
  }

  void _drawClock(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
    canvas.drawLine(
      center,
      center + const Offset(0, -11),
      Paint()..color = color,
    );
    canvas.drawLine(
      center,
      center + const Offset(9, 4),
      Paint()..color = color,
    );
    canvas.drawCircle(center, 3, Paint()..color = color);
  }

  void _drawEcho(Canvas canvas, Offset center, Color color) {
    for (var index = 0; index < 3; index += 1) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 8.0 + index * 6),
        -.8,
        1.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 1 - index * .22),
      );
    }
    canvas.drawCircle(center - const Offset(8, 0), 4, Paint()..color = color);
  }

  void _drawRewind(Canvas canvas, Offset center, Color color) {
    final arrow = Path()
      ..moveTo(center.dx - 18, center.dy - 2)
      ..lineTo(center.dx - 7, center.dy - 13)
      ..lineTo(center.dx - 7, center.dy - 6)
      ..arcTo(
        Rect.fromCircle(center: center, radius: 14),
        math.pi * 1.25,
        math.pi * 1.35,
        false,
      );
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  void _drawValve(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );
    for (var index = 0; index < 4; index += 1) {
      final angle = index * math.pi / 2;
      canvas.drawLine(
        center + Offset(math.cos(angle) * 4, math.sin(angle) * 4),
        center + Offset(math.cos(angle) * 21, math.sin(angle) * 21),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  void _drawShard(Canvas canvas, Offset center, Color color) {
    final shard = Path()
      ..moveTo(center.dx, center.dy - 21)
      ..lineTo(center.dx + 15, center.dy - 2)
      ..lineTo(center.dx + 5, center.dy + 20)
      ..lineTo(center.dx - 14, center.dy + 8)
      ..close();
    canvas.drawPath(shard, Paint()..color = color.withValues(alpha: .34));
    canvas.drawPath(
      shard,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  void _drawCoil(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center - const Offset(10, 0),
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
    canvas.drawCircle(
      center + const Offset(10, 0),
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: .75),
    );
    canvas.drawCircle(center, 4, Paint()..color = color);
  }
}
