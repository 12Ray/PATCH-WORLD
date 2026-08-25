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

/// Visual grammar used to keep the four story bosses from feeling like the
/// same encounter with a different colour filter.
enum BossArenaIdentity {
  generic,
  overflowWarden,
  chronoJailer,
  kernelChimera,
  optimizer,
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
    this.identity = BossArenaIdentity.generic,
    bool initiallyCleared = false,
  }) : state = initiallyCleared
           ? BossArenaPresentationState.cleared
           : BossArenaPresentationState.dormant,
       super(priority: -20);

  final Color accentColor;
  final BossArenaIdentity identity;
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

    _drawArenaIdentity(canvas, intensity: intensity, pulse: pulse);

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

  void _drawArenaIdentity(
    Canvas canvas, {
    required double intensity,
    required double pulse,
  }) {
    switch (identity) {
      case BossArenaIdentity.generic:
        return;
      case BossArenaIdentity.overflowWarden:
        _drawPressureHangar(canvas, intensity: intensity, pulse: pulse);
      case BossArenaIdentity.chronoJailer:
        _drawTimePrison(canvas, intensity: intensity, pulse: pulse);
      case BossArenaIdentity.kernelChimera:
        _drawFusionFurnace(canvas, intensity: intensity, pulse: pulse);
      case BossArenaIdentity.optimizer:
        _drawOptimizerCore(canvas, intensity: intensity, pulse: pulse);
    }
  }

  void _drawPressureHangar(
    Canvas canvas, {
    required double intensity,
    required double pulse,
  }) {
    final gaugeCenter = Offset(size.x / 2, 214);
    final pipePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = const Color(0xFFCC7234).withValues(alpha: intensity * .32);
    for (final direction in const <double>[-1, 1]) {
      final x = size.x / 2 + direction * math.min(430, size.x * .31);
      canvas.drawPath(
        Path()
          ..moveTo(x, 72)
          ..lineTo(x, 188)
          ..quadraticBezierTo(x, 220, x - direction * 34, 220)
          ..lineTo(x - direction * 92, 220),
        pipePaint,
      );
      for (var vent = 0; vent < phaseIndex; vent += 1) {
        final ventX = x - direction * (28 + vent * 34);
        canvas.drawLine(
          Offset(ventX, size.y - 150),
          Offset(ventX, size.y - 245 - 14 * pulse),
          Paint()
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..color = const Color(
              0xFFFF754D,
            ).withValues(alpha: intensity * .38),
        );
      }
    }
    canvas.drawArc(
      Rect.fromCircle(center: gaugeCenter, radius: 76),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = accentColor.withValues(alpha: intensity * .72),
    );
    final needleAngle = math.pi + math.pi * (.18 + phaseIndex * .22) * pulse;
    canvas.drawLine(
      gaugeCenter,
      gaugeCenter + Offset(math.cos(needleAngle), math.sin(needleAngle)) * 62,
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFE8B5).withValues(alpha: .72),
    );
  }

  void _drawTimePrison(
    Canvas canvas, {
    required double intensity,
    required double pulse,
  }) {
    final center = Offset(size.x / 2, size.y * .42);
    final maximum = math.min(size.x, size.y) * .29;
    for (var ring = 0; ring < 3; ring += 1) {
      final radius = maximum - ring * 38;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _clock * (ring.isEven ? .18 : -.12),
        math.pi * (1.25 + ring * .16),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + (2 - ring).toDouble()
          ..color = accentColor.withValues(
            alpha: intensity * (.54 - ring * .09),
          ),
      );
    }
    for (var tick = 0; tick < 12; tick += 1) {
      final angle = tick * math.pi / 6;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (maximum - 12),
        center + direction * maximum,
        Paint()
          ..strokeWidth = tick % 3 == 0 ? 5 : 2
          ..color = const Color(0xFFC9BDFF).withValues(alpha: intensity * .7),
      );
    }
    final handAngle = -math.pi / 2 + _clock * (.32 + phaseIndex * .12);
    canvas.drawLine(
      center,
      center + Offset(math.cos(handAngle), math.sin(handAngle)) * maximum * .72,
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF2ECFF).withValues(alpha: .68 * pulse),
    );
  }

  void _drawFusionFurnace(
    Canvas canvas, {
    required double intensity,
    required double pulse,
  }) {
    final center = Offset(size.x / 2, size.y * .45);
    final splitWidth = math.min(460, size.x * .32);
    final left = const Color(0xFF43E5FF);
    final right = const Color(0xFFFF4FCA);
    for (var lane = 0; lane < 4; lane += 1) {
      final y = center.dy - 132 + lane * 88;
      final convergence = (lane - 1.5) * 24;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - splitWidth, y)
          ..quadraticBezierTo(
            center.dx - splitWidth * .34,
            y,
            center.dx - 26,
            center.dy + convergence,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = left.withValues(alpha: intensity * .56),
      );
      canvas.drawPath(
        Path()
          ..moveTo(center.dx + splitWidth, y)
          ..quadraticBezierTo(
            center.dx + splitWidth * .34,
            y,
            center.dx + 26,
            center.dy - convergence,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = right.withValues(alpha: intensity * .56),
      );
    }
    final coreRadius = 38 + phaseIndex * 8 + pulse * 5;
    final core = Path()
      ..moveTo(center.dx, center.dy - coreRadius)
      ..lineTo(center.dx + coreRadius, center.dy)
      ..lineTo(center.dx, center.dy + coreRadius)
      ..lineTo(center.dx - coreRadius, center.dy)
      ..close();
    canvas.drawPath(
      core,
      Paint()
        ..shader = Gradient.linear(
          Offset(center.dx - coreRadius, center.dy),
          Offset(center.dx + coreRadius, center.dy),
          <Color>[
            left.withValues(alpha: intensity * .58),
            right.withValues(alpha: intensity * .58),
          ],
        ),
    );
  }

  void _drawOptimizerCore(
    Canvas canvas, {
    required double intensity,
    required double pulse,
  }) {
    final center = Offset(size.x / 2, size.y * .43);
    final irisWidth = math.min(520.0, size.x * .36);
    final irisHeight = math.min(245.0, size.y * .29);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: irisWidth, height: irisHeight),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = accentColor.withValues(alpha: intensity * .65),
    );
    canvas.drawCircle(
      center,
      28 + phaseIndex * 8 + pulse * 5,
      Paint()
        ..color = const Color(0xFFFFF1FC).withValues(alpha: intensity * .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final scanX = 122 + ((_clock * (130 + phaseIndex * 38)) % (size.x - 244));
    canvas.drawLine(
      Offset(scanX, 116),
      Offset(scanX, size.y - 92),
      Paint()
        ..strokeWidth = 3
        ..color = accentColor.withValues(alpha: intensity * .48),
    );
    for (var prediction = 0; prediction < phaseIndex; prediction += 1) {
      final angle = _clock * .35 + prediction * math.pi * 2 / 3;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * 142,
        18 + prediction * 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFF62D7).withValues(alpha: intensity * .42),
      );
    }
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
