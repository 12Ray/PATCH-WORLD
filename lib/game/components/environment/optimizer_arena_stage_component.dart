import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

/// Optimizer-only environmental presentation that reacts to the live boss
/// phase without changing the shared story-map renderer.
final class OptimizerArenaStageComponent extends PositionComponent {
  OptimizerArenaStageComponent({required Vector2 worldSize})
    : super(size: worldSize.clone(), priority: -18);

  OptimizerPhase phase = OptimizerPhase.analyze;
  bool _coreExposed = false;
  double _clock = 0;
  double _transitionFlash = 0;

  bool get isCoreExposed => _coreExposed;

  void setPhase(OptimizerPhase next) {
    if (phase == next) return;
    phase = next;
    _transitionFlash = 1;
    if (next == OptimizerPhase.analyze ||
        next == OptimizerPhase.predict ||
        next == OptimizerPhase.perfect) {
      _coreExposed = false;
    }
  }

  void revealCore() {
    _coreExposed = true;
    _transitionFlash = 1;
  }

  @override
  void update(double dt) {
    _clock += dt;
    _transitionFlash = math.max(0, _transitionFlash - dt * 1.35);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final accent = switch (phase) {
      OptimizerPhase.analyze => const Color(0xFF36E1FF),
      OptimizerPhase.predict => const Color(0xFFFF4FD8),
      OptimizerPhase.perfect => const Color(0xFFF4F7FF),
      OptimizerPhase.overflow ||
      OptimizerPhase.defeated => const Color(0xFFFFD35A),
    };
    final pulse = .72 + math.sin(_clock * 2.8).abs() * .28;
    final center = Offset(size.x / 2, 350);

    canvas.drawRect(
      size.toRect(),
      Paint()
        ..shader = Gradient.radial(
          center,
          math.max(size.x, size.y) * .52,
          <Color>[
            accent.withValues(alpha: .055 * pulse),
            const Color(0x00000000),
          ],
        ),
    );

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = phase == OptimizerPhase.perfect ? 3 : 2
      ..color = accent.withValues(alpha: .20 * pulse);
    final ringCount = switch (phase) {
      OptimizerPhase.analyze => 3,
      OptimizerPhase.predict => 5,
      OptimizerPhase.perfect => 7,
      OptimizerPhase.overflow || OptimizerPhase.defeated => 4,
    };
    for (var ring = 0; ring < ringCount; ring += 1) {
      final radius = 88.0 + ring * 54 + math.sin(_clock * 2 + ring) * 5;
      canvas.drawCircle(center, radius, ringPaint);
    }

    switch (phase) {
      case OptimizerPhase.analyze:
        _drawAnalysisLanes(canvas, accent);
      case OptimizerPhase.predict:
        _drawPredictionCones(canvas, accent);
      case OptimizerPhase.perfect:
        _drawPerfectPressure(canvas, accent);
      case OptimizerPhase.overflow || OptimizerPhase.defeated:
        _drawCollapseFractures(canvas, accent);
    }

    if (_coreExposed) {
      final corePulse = .78 + math.sin(_clock * 7).abs() * .22;
      canvas.drawCircle(
        center,
        38 + corePulse * 8,
        Paint()
          ..color = const Color(0xFFFFF3B0).withValues(alpha: .52 * corePulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawCircle(center, 27, Paint()..color = const Color(0xFFF4F7FF));
      canvas.drawLine(
        center + const Offset(0, 34),
        const Offset(960, 944),
        Paint()
          ..strokeWidth = 4
          ..color = const Color(0x99FFD35A),
      );
    }

    if (_transitionFlash > 0) {
      canvas.drawRect(
        size.toRect(),
        Paint()..color = accent.withValues(alpha: _transitionFlash * .075),
      );
    }
    super.render(canvas);
  }

  void _drawAnalysisLanes(Canvas canvas, Color accent) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accent.withValues(alpha: .15);
    for (var lane = 0; lane < 7; lane += 1) {
      final y = 170.0 + lane * 96;
      final drift = math.sin(_clock * 1.4 + lane) * 28;
      canvas.drawLine(Offset(180 + drift, y), Offset(size.x - 180, y), paint);
    }
  }

  void _drawPredictionCones(Canvas canvas, Color accent) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = accent.withValues(alpha: .20);
    for (final direction in const <double>[-1, 1]) {
      final path = Path()
        ..moveTo(size.x / 2, 350)
        ..lineTo(size.x / 2 + direction * 560, 820)
        ..lineTo(size.x / 2 + direction * 360, 820)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawPerfectPressure(Canvas canvas, Color accent) {
    final terminalCenter = const Offset(960, 980);
    canvas.drawCircle(
      terminalCenter,
      78 + math.sin(_clock * 4).abs() * 8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xAA45F3A6),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent.withValues(alpha: .22);
    for (var index = 0; index < 8; index += 1) {
      final angle = index * math.pi / 4 + _clock * .18;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        const Offset(960, 350) + direction * 130,
        const Offset(960, 350) + direction * 330,
        paint,
      );
    }
  }

  void _drawCollapseFractures(Canvas canvas, Color accent) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = accent.withValues(alpha: .25);
    for (var ray = 0; ray < 12; ray += 1) {
      final angle = ray * math.pi / 6 + .11;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final side = Offset(-direction.dy, direction.dx);
      final origin = const Offset(960, 350) + direction * 72;
      final elbow = origin + direction * 110 + side * (ray.isEven ? 24 : -24);
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(
            elbow.dx + direction.dx * 150,
            elbow.dy + direction.dy * 150,
          ),
        paint,
      );
    }
  }
}

/// A visible solid whose motion changes with the Optimizer's phase. Its world
/// position is also its collision position, so the platform cannot desync from
/// its artwork.
final class OptimizerPhasePlatformComponent extends PlatformSurfaceComponent {
  OptimizerPhasePlatformComponent({
    required Vector2 start,
    required this.end,
    required super.size,
    required this.periodSeconds,
  }) : _start = start.clone(),
       super(position: start, style: PlatformSurfaceStyle.optimizer);

  final Vector2 _start;
  final Vector2 end;
  final double periodSeconds;
  OptimizerPhase phase = OptimizerPhase.analyze;
  double _clock = 0;
  final Vector2 _frameDisplacement = Vector2.zero();

  @override
  Vector2 get frameDisplacement => _frameDisplacement;

  void setPhase(OptimizerPhase next) => phase = next;

  @override
  ArtV3EnvironmentRole get foregroundRole => ArtV3EnvironmentRole.statePlatform;

  @override
  void update(double dt) {
    final simulationDt = isMounted ? game.clock.enemyDt : dt;
    final previousPosition = position.clone();
    if (simulationDt > 0) _clock += simulationDt;
    final midpoint = (_start + end) / 2;
    final halfTravel = (end - _start) / 2;
    final amplitude = switch (phase) {
      OptimizerPhase.analyze => .72,
      OptimizerPhase.predict => 1.0,
      OptimizerPhase.perfect => .38,
      OptimizerPhase.overflow || OptimizerPhase.defeated => 0.0,
    };
    final speed = switch (phase) {
      OptimizerPhase.analyze => .78,
      OptimizerPhase.predict => 1.42,
      OptimizerPhase.perfect => .62,
      OptimizerPhase.overflow || OptimizerPhase.defeated => .3,
    };
    final wave = math.sin(
      (_clock / periodSeconds) * math.pi * 2 * speed - math.pi / 2,
    );
    final desired = midpoint + halfTravel * (wave * amplitude);
    final blend = math.min(1.0, simulationDt * 5);
    position += (desired - position) * blend;
    if (simulationDt > 0) {
      _frameDisplacement.setFrom(position - previousPosition);
    } else {
      _frameDisplacement.setZero();
    }
    super.update(dt);
  }
}

/// Phase-authored break cycle with an explicit warning window. Broken artwork
/// and solid collision always change on the same tick.
final class OptimizerPhaseBreakablePlatformComponent
    extends PlatformSurfaceComponent {
  OptimizerPhaseBreakablePlatformComponent({
    required super.position,
    required super.size,
  }) : super(style: PlatformSurfaceStyle.optimizer);

  OptimizerPhase phase = OptimizerPhase.analyze;
  double _clock = 0;
  bool _broken = false;
  double _warningProgress = 0;

  bool get isBroken => _broken;
  double get warningProgress => _warningProgress;

  void setPhase(OptimizerPhase next) {
    if (phase == next) return;
    phase = next;
    _clock = 0;
    _broken = false;
    _warningProgress = 0;
  }

  @override
  ArtV3EnvironmentRole get foregroundRole => ArtV3EnvironmentRole.statePlatform;

  @override
  bool get isSolid => !_broken && super.isSolid;

  @override
  void update(double dt) {
    final simulationDt = isMounted ? game.clock.enemyDt : dt;
    if (simulationDt <= 0) {
      super.update(dt);
      return;
    }
    final timing = switch (phase) {
      OptimizerPhase.predict => (
        period: 3.7,
        warn: 2.0,
        breakAt: 2.55,
        mend: 3.25,
      ),
      OptimizerPhase.perfect => (
        period: 4.5,
        warn: 2.55,
        breakAt: 3.15,
        mend: 3.75,
      ),
      _ => null,
    };
    if (timing == null) {
      _clock = 0;
      _broken = false;
      _warningProgress = 0;
    } else {
      _clock = (_clock + simulationDt) % timing.period;
      _broken = _clock >= timing.breakAt && _clock < timing.mend;
      _warningProgress = _clock >= timing.warn && _clock < timing.breakAt
          ? ((_clock - timing.warn) / (timing.breakAt - timing.warn)).clamp(
              0,
              1,
            )
          : 0;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_broken) return;
    super.render(canvas);
    if (_warningProgress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + _warningProgress * 2
      ..color = Color.lerp(
        const Color(0xFFFFD35A),
        const Color(0xFFFF4FD8),
        _warningProgress,
      )!;
    final center = size.x / 2;
    canvas.drawPath(
      Path()
        ..moveTo(center - 28, 2)
        ..lineTo(center - 8, size.y - 3)
        ..lineTo(center + 4, 5)
        ..lineTo(center + 30, size.y - 3),
      paint,
    );
  }
}

/// A phase-aware arena laser with long, deterministic safe windows around the
/// central Perfect-state terminal route.
final class OptimizerPhaseLaserComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  OptimizerPhaseLaserComponent({
    required super.position,
    required super.size,
    required this.sourceId,
    this.phaseOffset = 0,
  }) : super(priority: 8);

  final String sourceId;
  final double phaseOffset;
  OptimizerPhase phase = OptimizerPhase.analyze;
  double _clock = 0;
  bool _wasActive = false;
  bool _damagedThisPulse = false;

  ({double active, double inactive})? get _timing => switch (phase) {
    OptimizerPhase.analyze => (active: .9, inactive: 1.55),
    OptimizerPhase.predict => (active: 1.2, inactive: .82),
    OptimizerPhase.perfect => (active: .72, inactive: 1.28),
    OptimizerPhase.overflow || OptimizerPhase.defeated => null,
  };

  bool get isActive {
    final timing = _timing;
    if (timing == null) return false;
    final cycle = timing.active + timing.inactive;
    final local = (_clock + phaseOffset) % cycle;
    return local >= timing.inactive;
  }

  double get warningProgress {
    final timing = _timing;
    if (timing == null || isActive) return 0;
    final cycle = timing.active + timing.inactive;
    final local = (_clock + phaseOffset) % cycle;
    const warningWindow = .48;
    return ((local - (timing.inactive - warningWindow)) / warningWindow).clamp(
      0,
      1,
    );
  }

  void setPhase(OptimizerPhase next) {
    if (phase == next) return;
    phase = next;
    _clock = 0;
    _wasActive = false;
    _damagedThisPulse = false;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(size: size));
  }

  @override
  void update(double dt) {
    final simulationDt = isMounted ? game.clock.enemyDt : dt;
    if (simulationDt > 0) _clock += simulationDt;
    final active = isActive;
    if (isMounted && active && !_wasActive) {
      _damageOverlappingPlayer();
    } else if (!active) {
      _damagedThisPulse = false;
    }
    _wasActive = active;
    super.update(dt);
  }

  void _damageOverlappingPlayer() {
    final player = game.world.player;
    final laserBounds = Rect.fromLTWH(position.x, position.y, size.x, size.y);
    if (laserBounds.overlaps(player.damageHitboxBounds)) _damagePlayer(player);
  }

  void _damagePlayer(PlayerComponent player) {
    if (_damagedThisPulse) return;
    _damagedThisPulse = true;
    player.takeDamage(1, causeId: sourceId);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (isActive && other is PlayerComponent) {
      _damagePlayer(other);
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    final active = isActive;
    final warning = warningProgress;
    final color = active
        ? const Color(0xFFFF4FD8)
        : Color.lerp(
            const Color(0x3345516C),
            const Color(0xAAFFD35A),
            warning,
          )!;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: active ? math.min(8, size.x) : math.min(3, size.x),
        height: size.y,
      ),
      Paint()
        ..color = color
        ..maskFilter = active
            ? const MaskFilter.blur(BlurStyle.normal, 5)
            : null,
    );
    for (final y in <double>[0, size.y - 12]) {
      canvas.drawRect(
        Rect.fromLTWH(-9, y, size.x + 18, 12),
        Paint()..color = const Color(0xFF55516C),
      );
    }
    super.render(canvas);
  }
}
