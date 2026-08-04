import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class OptimizerVolleyTelegraphComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  OptimizerVolleyTelegraphComponent({
    required super.position,
    required this.laneCount,
    required this.onResolved,
    this.warningSeconds = 0.46,
  }) : super(priority: 17);

  final int laneCount;
  final void Function() onResolved;
  final double warningSeconds;
  double _remaining = 0;
  bool _resolved = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _remaining = warningSeconds;
  }

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (!_resolved && enemyDt > 0) {
      _remaining -= enemyDt;
      if (_remaining <= 0) {
        _resolved = true;
        onResolved();
        removeFromParent();
      }
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (1 - _remaining / warningSeconds).clamp(0.0, 1.0);
    for (var index = 0; index < laneCount; index += 1) {
      final angle = math.pi * 2 * (index + 0.5) / laneCount;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        direction * 58,
        direction * 680,
        Paint()
          ..strokeWidth = 1 + progress * 2.2
          ..color = Color.fromRGBO(255, 79, 216, 0.14 + progress * 0.48),
      );
    }
    canvas.drawCircle(
      Offset.zero,
      54 + progress * 22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + progress * 3
        ..color = const Color(0xAA36E1FF),
    );
  }
}
