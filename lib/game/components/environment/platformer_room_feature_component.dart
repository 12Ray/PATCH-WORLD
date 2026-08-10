import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

enum RoomHazardStyle { spikes, laser }

final class RoomHazardComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  RoomHazardComponent({
    required super.position,
    required super.size,
    required this.style,
    required this.sourceId,
    this.surfaceStyle = PlatformSurfaceStyle.damage,
  }) : super(priority: 8);

  final RoomHazardStyle style;
  final String sourceId;
  final PlatformSurfaceStyle surfaceStyle;
  double _phase = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(size: size));
  }

  @override
  void update(double dt) {
    _phase += dt;
    super.update(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is PlayerComponent) {
      other.takeDamage(1, causeId: sourceId);
      if (style == RoomHazardStyle.spikes) {
        other.applyExternalImpulse(Vector2(0, -260));
      }
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    final glow = .55 + math.sin(_phase * 7) * .18;
    switch (style) {
      case RoomHazardStyle.spikes:
        final path = Path();
        const spikeWidth = 16.0;
        for (double x = 0; x < size.x; x += spikeWidth) {
          path
            ..moveTo(x, size.y)
            ..lineTo(math.min(x + spikeWidth / 2, size.x), 0)
            ..lineTo(math.min(x + spikeWidth, size.x), size.y)
            ..close();
        }
        canvas.drawPath(
          path,
          Paint()..color = surfaceStyle.secondaryAccent.withValues(alpha: glow),
        );
      case RoomHazardStyle.laser:
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.x / 2, size.y / 2),
            width: math.min(6, size.x),
            height: size.y,
          ),
          Paint()
            ..color = surfaceStyle.secondaryAccent.withValues(alpha: glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        for (final y in <double>[0, size.y - 8]) {
          canvas.drawRect(
            Rect.fromLTWH(0, y, size.x, 8),
            Paint()..color = surfaceStyle.bodyHighlight,
          );
        }
    }
    super.render(canvas);
  }
}

final class JumpPadComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  JumpPadComponent({
    required super.position,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(size: Vector2(54, 12), priority: 7);

  final PlatformSurfaceStyle style;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(size: size));
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is PlayerComponent) {
      other.applyExternalImpulse(Vector2(0, -520));
      unawaited(game.audio.playJumpPad());
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(size.x, 0),
          <Color>[style.bodyColor, style.bodyHighlight, style.bodyColor],
          <double>[0, .5, 1],
        ),
    );
    for (final x in <double>[14, 27, 40]) {
      final arrow = Path()
        ..moveTo(x - 5, 8)
        ..lineTo(x, 3)
        ..lineTo(x + 5, 8);
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = style.accentColor,
      );
    }
    super.render(canvas);
  }
}

final class CheckpointBeaconComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  CheckpointBeaconComponent({
    required super.position,
    required this.index,
    this.onActivated,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(size: Vector2(34, 58), anchor: Anchor.bottomCenter, priority: 6);

  final int index;
  final void Function(int index, Vector2 respawnPoint)? onActivated;
  final PlatformSurfaceStyle style;
  double _phase = 0;
  bool _active = false;

  bool get isActive => _active;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox.relative(Vector2(.85, 1), parentSize: size));
  }

  @override
  void update(double dt) {
    _phase += dt;
    if (!_active && isMounted && game.world.isMounted) {
      final player = game.world.player;
      final dx = player.position.x - position.x;
      final dy = player.position.y - (position.y - 28);
      if (dx * dx + dy * dy <= 48 * 48) {
        _activate();
      }
    }
    super.update(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (!_active && other is PlayerComponent) {
      _activate();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  void _activate() {
    if (_active) return;
    _active = true;
    onActivated?.call(index, Vector2(position.x, position.y - 28));
    unawaited(game.audio.playCheckpoint());
  }

  @override
  void render(Canvas canvas) {
    final pulse = 10 + math.sin(_phase * 4 + index) * 2;
    final center = Offset(size.x / 2, 17);
    canvas.drawCircle(
      center,
      pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _active ? const Color(0xFF45F3A6) : const Color(0xAAFFD35A),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 4, 27, 8, 25),
      Paint()..color = style.bodyHighlight,
    );
    canvas.drawRect(
      Rect.fromLTWH(4, 50, size.x - 8, 8),
      Paint()..color = style.bodyColor,
    );
    canvas.drawCircle(
      center,
      _active ? 6 : 4,
      Paint()
        ..color = _active ? const Color(0xFF45F3A6) : const Color(0xFFFFD35A),
    );
    super.render(canvas);
  }
}

final class BossSealGateComponent extends PlatformSurfaceComponent {
  BossSealGateComponent({
    required super.position,
    required super.size,
    required super.style,
  }) : super(isBoundary: true);

  bool _unlocked = false;
  double _unlockProgress = 0;

  bool get isUnlocked => _unlocked;

  @override
  bool get isSolid => !_unlocked && super.isSolid;

  void unlock() => _unlocked = true;

  @override
  void update(double dt) {
    if (_unlocked) _unlockProgress = math.min(1, _unlockProgress + dt * 2.5);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_unlockProgress >= 1) return;
    final alpha = ((1 - _unlockProgress) * 220).round();
    final visibleHeight = size.y * (1 - _unlockProgress);
    final rect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: size.x,
      height: visibleHeight,
    );
    canvas.drawRect(rect, Paint()..color = Color.fromARGB(alpha, 255, 79, 216));
    canvas.drawRect(
      rect.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.fromARGB(alpha, 255, 211, 90),
    );
  }
}

final class PulsingLaserComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  PulsingLaserComponent({
    required super.position,
    required super.size,
    required this.sourceId,
    this.activeSeconds = 1.4,
    this.inactiveSeconds = 1.0,
    this.phaseOffset = 0,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(priority: 8);

  final String sourceId;
  final double activeSeconds;
  final double inactiveSeconds;
  final double phaseOffset;
  final PlatformSurfaceStyle style;
  double _elapsed = 0;
  bool _wasActive = false;

  bool get isActive =>
      ((_elapsed + phaseOffset) % (activeSeconds + inactiveSeconds)) <
      activeSeconds;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _wasActive = isActive;
    await add(RectangleHitbox(size: size));
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    final active = isActive;
    if (active && !_wasActive) unawaited(game.audio.playLaserFire());
    _wasActive = active;
    super.update(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (isActive && other is PlayerComponent) {
      other.takeDamage(1, causeId: sourceId);
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    final color = isActive
        ? style.secondaryAccent
        : style.bodyHighlight.withAlpha(55);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: math.min(size.x, 7),
        height: size.y,
      ),
      Paint()
        ..color = color
        ..maskFilter = isActive
            ? const MaskFilter.blur(BlurStyle.normal, 4)
            : null,
    );
  }
}

final class CrusherHazardComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  CrusherHazardComponent({
    required Vector2 start,
    required this.end,
    required super.size,
    required this.sourceId,
    this.periodSeconds = 2.8,
    this.style = PlatformSurfaceStyle.damage,
  }) : _start = start.clone(),
       super(position: start, priority: 9);

  final Vector2 _start;
  final Vector2 end;
  final String sourceId;
  final double periodSeconds;
  final PlatformSurfaceStyle style;
  double _elapsed = 0;
  bool _impactArmed = true;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RectangleHitbox(size: size));
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    final phase = (_elapsed / periodSeconds) * math.pi * 2;
    final t = (math.sin(phase) + 1) / 2;
    position.setFrom(_start + (end - _start) * t);
    if (t < .78) _impactArmed = true;
    if (_impactArmed && t > .97) {
      _impactArmed = false;
      unawaited(game.audio.playCrusherImpact());
    }
    super.update(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is PlayerComponent) {
      other.takeDamage(1, causeId: sourceId);
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, size.y), <Color>[
          style.bodyHighlight,
          style.bodyColor,
        ]),
    );
    for (double x = 0; x < size.x; x += 16) {
      final tooth = Path()
        ..moveTo(x, size.y)
        ..lineTo(x + 8, size.y + 10)
        ..lineTo(x + 16, size.y)
        ..close();
      canvas.drawPath(tooth, Paint()..color = style.secondaryAccent);
    }
  }
}
