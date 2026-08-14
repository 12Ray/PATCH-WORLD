import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/patch_world_game.dart';

/// Visible hub landmark for the final Optimizer route.
///
/// Previously the route simply did not exist until all cores were collected,
/// which made the lock condition hard to understand. This gate remains in the
/// hub and exposes the exact 0/3..3/3 signature progress.
final class CoreSignatureGateComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  CoreSignatureGateComponent({
    required super.position,
    required this.acquiredSignatures,
    required this.requiredSignatures,
  }) : assert(acquiredSignatures >= 0),
       assert(acquiredSignatures <= requiredSignatures),
       super(size: Vector2(138, 132), anchor: Anchor.bottomCenter, priority: 5);

  final int acquiredSignatures;
  final int requiredSignatures;
  double _clock = 0;

  bool get isUnlocked => acquiredSignatures >= requiredSignatures;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await addAll(<Component>[
      TextComponent(
        text: game.localization.text('gate.optimizerCore'),
        position: Vector2(size.x / 2, -7),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFFF3F7FF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
      ),
      TextComponent(
        text: game.localization.text(
          'gate.coreProgress',
          parameters: <String, Object>{
            'current': acquiredSignatures,
            'required': requiredSignatures,
          },
        ),
        position: Vector2(size.x / 2, 16),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: isUnlocked
                ? const Color(0xFF45F3A6)
                : const Color(0xFFFFD35A),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ),
    ]);
  }

  @override
  void update(double dt) {
    _clock += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final arch = RRect.fromRectAndCorners(
      Rect.fromLTWH(10, 27, size.x - 20, size.y - 27),
      topLeft: const Radius.circular(42),
      topRight: const Radius.circular(42),
    );
    canvas.drawRRect(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xFF29345D),
    );
    canvas.drawRRect(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFD35A).withValues(alpha: .72),
    );
    for (var index = 0; index < requiredSignatures; index += 1) {
      final active = index < acquiredSignatures;
      final center = Offset(43.0 + index * 26, 46);
      canvas.drawCircle(
        center,
        8 + (active ? math.sin(_clock * 3 + index).abs() * 2 : 0),
        Paint()
          ..color = active ? const Color(0xFF45F3A6) : const Color(0xFF11182C),
      );
      canvas.drawCircle(
        center,
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = active ? const Color(0xFF36E1FF) : const Color(0xFF59617A),
      );
    }
    if (!isUnlocked) {
      final barrier = Rect.fromLTWH(27, 61, size.x - 54, size.y - 65);
      canvas.drawRect(barrier, Paint()..color = const Color(0xAAFF4FD8));
      for (double y = barrier.top + 7; y < barrier.bottom; y += 13) {
        canvas.drawLine(
          Offset(barrier.left, y),
          Offset(barrier.right, y),
          Paint()
            ..strokeWidth = 1
            ..color = const Color(0x99FFD35A),
        );
      }
    }
    super.render(canvas);
  }
}
