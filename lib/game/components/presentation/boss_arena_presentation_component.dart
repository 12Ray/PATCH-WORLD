import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/patch_world_game.dart';

enum BossArenaPresentationState {
  dormant,
  intro,
  phaseOne,
  phaseTwo,
  phaseThree,
  cleared,
}

/// Shared environmental language for the three regional boss arenas.
///
/// It deliberately sits behind collision geometry and combatants. Phase
/// changes alter the arena pulse and circuit density, while a cleared arena
/// keeps a calm core sigil so revisiting the room visibly preserves progress.
final class BossArenaPresentationComponent extends PositionComponent {
  BossArenaPresentationComponent({
    required super.size,
    required this.accentColor,
    bool initiallyCleared = false,
  }) : state = initiallyCleared
           ? BossArenaPresentationState.cleared
           : BossArenaPresentationState.dormant,
       super(priority: -20);

  final Color accentColor;
  BossArenaPresentationState state;
  double _clock = 0;
  double _transitionFlash = 0;

  bool get isCleared => state == BossArenaPresentationState.cleared;
  int get phaseIndex => switch (state) {
    BossArenaPresentationState.dormant => 0,
    BossArenaPresentationState.intro ||
    BossArenaPresentationState.phaseOne => 1,
    BossArenaPresentationState.phaseTwo => 2,
    BossArenaPresentationState.phaseThree => 3,
    BossArenaPresentationState.cleared => 4,
  };

  void beginIntro() => _setState(BossArenaPresentationState.intro);
  void beginPhaseOne() => _setState(BossArenaPresentationState.phaseOne);
  void beginPhaseTwo() => _setState(BossArenaPresentationState.phaseTwo);
  void beginPhaseThree() => _setState(BossArenaPresentationState.phaseThree);
  void markCleared() => _setState(BossArenaPresentationState.cleared);

  void _setState(BossArenaPresentationState next) {
    if (state == next) return;
    state = next;
    _transitionFlash = 1;
  }

  @override
  void update(double dt) {
    _clock += dt;
    _transitionFlash = math.max(0, _transitionFlash - dt * 1.8);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final intensity = switch (state) {
      BossArenaPresentationState.dormant => .12,
      BossArenaPresentationState.intro => .48,
      BossArenaPresentationState.phaseOne => .28,
      BossArenaPresentationState.phaseTwo => .42,
      BossArenaPresentationState.phaseThree => .62,
      BossArenaPresentationState.cleared => .22,
    };
    final pulse = .72 + math.sin(_clock * (2.2 + phaseIndex)) * .18;
    final arenaRect = Rect.fromLTWH(96, 104, size.x - 192, size.y - 160);

    canvas.drawRect(
      size.toRect(),
      Paint()..color = const Color(0xFF030611).withValues(alpha: .18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(arenaRect, const Radius.circular(34)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + phaseIndex * .6
        ..color = accentColor.withValues(alpha: intensity * pulse),
    );

    final circuitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accentColor.withValues(alpha: intensity * .55);
    final laneCount = 4 + phaseIndex * 2;
    for (var lane = 0; lane < laneCount; lane += 1) {
      final inset = 22.0 + lane * 28;
      final y = 138.0 + lane * ((size.y - 270) / math.max(1, laneCount - 1));
      final drift = math.sin(_clock * 1.8 + lane) * 10;
      final path = Path()
        ..moveTo(102, y)
        ..lineTo(inset + 110 + drift, y)
        ..lineTo(inset + 142 + drift, y - 18)
        ..lineTo(size.x - 102, y - 18);
      canvas.drawPath(path, circuitPaint);
    }

    if (state == BossArenaPresentationState.phaseTwo ||
        state == BossArenaPresentationState.phaseThree) {
      final warningAlpha = state == BossArenaPresentationState.phaseThree
          ? .32
          : .18;
      for (final x in <double>[170, size.x - 170]) {
        canvas.drawCircle(
          Offset(x, 250),
          58 + math.sin(_clock * 4 + x).abs() * 12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = const Color(0xFFFF4FD8).withValues(alpha: warningAlpha),
        );
      }
    }

    if (state == BossArenaPresentationState.cleared) {
      final center = Offset(size.x / 2, size.y / 2 + 12);
      for (var ring = 0; ring < 3; ring += 1) {
        canvas.drawCircle(
          center,
          52 + ring * 22 + math.sin(_clock * 2 + ring) * 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 - ring * .55
            ..color = accentColor.withValues(alpha: .48 - ring * .1),
        );
      }
      canvas.drawCircle(
        center,
        18 + math.sin(_clock * 3).abs() * 4,
        Paint()
          ..color = const Color(0xFF45F3A6).withValues(alpha: .72)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    if (_transitionFlash > 0) {
      canvas.drawRect(
        size.toRect(),
        Paint()..color = accentColor.withValues(alpha: _transitionFlash * .1),
      );
    }
    super.render(canvas);
  }
}

enum BossNameCardStyle { entrance, victory }

/// World-space cinematic card used for boss introductions and core rewards.
final class BossNameCardComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  BossNameCardComponent({
    required Vector2 center,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.style = BossNameCardStyle.entrance,
    this.duration = 2.8,
  }) : super(
         position: center,
         size: Vector2(610, 104),
         anchor: Anchor.center,
         priority: 60,
       );

  final String title;
  final String subtitle;
  final Color accentColor;
  final BossNameCardStyle style;
  final double duration;
  double _elapsed = 0;

  double get revealProgress => (_elapsed / .45).clamp(0, 1).toDouble();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await addAll(<Component>[
      TextComponent(
        text: title,
        position: Vector2(size.x / 2, 31),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: const Color(0xFFF7FAFF),
            fontSize: style == BossNameCardStyle.entrance ? 27 : 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
      ),
      TextComponent(
        text: subtitle,
        position: Vector2(size.x / 2, 70),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: accentColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.25,
          ),
        ),
      ),
    ]);
  }

  @override
  void update(double dt) {
    _elapsed += isMounted ? game.clock.realDt : dt;
    if (_elapsed >= duration) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final reveal = revealProgress;
    final halfWidth = size.x * reveal / 2;
    final centerX = size.x / 2;
    final body = Rect.fromLTRB(
      centerX - halfWidth,
      5,
      centerX + halfWidth,
      size.y - 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(8)),
      Paint()..color = const Color(0xE6121727),
    );
    canvas.drawLine(
      Offset(centerX - halfWidth, 4),
      Offset(centerX + halfWidth, 4),
      Paint()
        ..strokeWidth = 3
        ..color = accentColor,
    );
    canvas.drawLine(
      Offset(centerX - halfWidth, size.y - 4),
      Offset(centerX + halfWidth, size.y - 4),
      Paint()
        ..strokeWidth = 2
        ..color = style == BossNameCardStyle.victory
            ? const Color(0xFF45F3A6)
            : accentColor,
    );
    super.render(canvas);
  }
}
