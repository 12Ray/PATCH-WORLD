import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/survival/survival_phase_eleven.dart';

final class SurvivalRegionObjectiveComponent extends CircleComponent {
  SurvivalRegionObjectiveComponent({
    required super.position,
    required this.region,
    required this.kind,
  }) : super(
         radius: 38,
         anchor: Anchor.center,
         priority: 32,
         paint: Paint()..color = const Color(0x00000000),
       );

  final SurvivalNexusRegion region;
  final SurvivalRegionEventKind kind;
  double progress = 0;
  bool carrying = false;
  double _phase = 0;

  void setProgress(double value) {
    progress = value.clamp(0, 1).toDouble();
  }

  @override
  void update(double dt) {
    _phase += dt.clamp(0, .05);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    final accent = switch (kind) {
      SurvivalRegionEventKind.relayRepair => const Color(0xFF45F3A6),
      SurvivalRegionEventKind.escort => const Color(0xFF36E1FF),
      SurvivalRegionEventKind.riftSeal => const Color(0xFFFF4FD8),
      SurvivalRegionEventKind.riskCache => const Color(0xFFFFC857),
    };
    final pulse = 1 + math.sin(_phase * 5) * .08;
    canvas.drawCircle(
      center,
      31 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = accent.withValues(alpha: .75),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 25),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFFFFF),
    );
    switch (kind) {
      case SurvivalRegionEventKind.relayRepair:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 11, height: 25),
          Paint()..color = accent,
        );
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 25, height: 11),
          Paint()..color = accent,
        );
      case SurvivalRegionEventKind.escort:
        final drone = Path()
          ..moveTo(center.dx, center.dy - 14)
          ..lineTo(center.dx + 16, center.dy + 10)
          ..lineTo(center.dx, center.dy + 5)
          ..lineTo(center.dx - 16, center.dy + 10)
          ..close();
        canvas.drawPath(drone, Paint()..color = accent);
      case SurvivalRegionEventKind.riftSeal:
        canvas.drawLine(
          center - const Offset(13, 13),
          center + const Offset(13, 13),
          Paint()
            ..color = accent
            ..strokeWidth = 5,
        );
        canvas.drawLine(
          center - const Offset(-13, 13),
          center + const Offset(-13, 13),
          Paint()
            ..color = accent
            ..strokeWidth = 5,
        );
      case SurvivalRegionEventKind.riskCache:
        final cache = Rect.fromCenter(center: center, width: 25, height: 19);
        canvas.drawRect(cache, Paint()..color = accent);
        canvas.drawLine(
          Offset(cache.left, cache.center.dy),
          Offset(cache.right, cache.center.dy),
          Paint()
            ..color = const Color(0xFF111827)
            ..strokeWidth = 3,
        );
        if (carrying) {
          canvas.drawCircle(
            center,
            18,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFFF6464),
          );
        }
    }
    super.render(canvas);
  }
}
