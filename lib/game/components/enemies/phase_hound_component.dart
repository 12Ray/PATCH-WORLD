import 'dart:async';
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';

enum PhaseHoundState { stalk, telegraph, dash, recovery }

/// A survival-only hunter that breaks circular kiting with a readable dash.
final class PhaseHoundComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget, DuplicateSource {
  PhaseHoundComponent({
    required this.entityId,
    required super.position,
    required this.onDefeated,
    this.targetPosition,
    this.onPerfectDodge,
    this.onBreakDefeated,
  }) : healthState = HealthState(max: maxHealth, current: maxHealth),
       super(
         size: Vector2(38, 30),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 12,
       );

  static const int maxHealth = 3;
  static const double stalkSeconds = 1.0;
  static const double telegraphSeconds = 0.65;
  static const double dashSeconds = 0.32;
  static const double recoverySeconds = 0.85;
  static const double stalkSpeed = 82;
  static const double dashSpeed = 330;
  static const double dashHitRadius = 30;
  static const double perfectDodgeRadius = 70;
  static const int recoveryDamageBonus = 1;

  @override
  final String entityId;
  final void Function() onDefeated;
  final Vector2 Function()? targetPosition;
  final void Function()? onPerfectDodge;
  final void Function(bool perfectDodgeLinked)? onBreakDefeated;
  final HealthState healthState;
  final Vector2 _previousPosition = Vector2.zero();
  Vector2 _lockedDirection = Vector2(1, 0);
  EntitySpriteVisual? _visual;
  PhaseHoundState state = PhaseHoundState.stalk;
  double stateTimer = stalkSeconds;
  bool _dashHitClaimed = false;
  bool _duplicateClaimed = false;
  bool _defeatReported = false;
  bool _dodgeReported = false;
  double _dashClosestApproach = double.infinity;
  TextComponent? _stateLabel;
  String? _stateCue;

  Vector2 get lockedDirection => _lockedDirection.clone();
  String? get stateCue => _stateCue;

  @override
  Vector2 get duplicatePosition => position;

  @override
  DuplicateArchetype get duplicateArchetype => DuplicateArchetype.crawler;

  @override
  bool claimDuplicate() {
    if (_duplicateClaimed || isRemoving) return false;
    _duplicateClaimed = true;
    return true;
  }

  bool claimDashHit() {
    if (state != PhaseHoundState.dash || _dashHitClaimed) return false;
    _dashHitClaimed = true;
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    unawaited(_loadVisual());
    await add(
      RectangleHitbox.relative(
        Vector2.all(0.72),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  Future<void> _loadVisual() async {
    try {
      final runImage = await game.images.load(
        'sprites/animations/phase-hound-run.png',
      );
      final runFrames = List.generate(
        6,
        (index) => Sprite(
          runImage,
          srcPosition: Vector2(index * 256.0, 0),
          srcSize: Vector2.all(256),
        ),
      );
      final visual = EntitySpriteVisual(
        sprite: runFrames.first,
        size: Vector2(78, 66),
        parentSize: size,
        bobAmplitude: 0.7,
        bobSpeed: 8,
        rotationAmplitude: 0.018,
      );
      if (isRemoving) return;
      _visual = visual;
      await add(visual);
      visual.setDefaultAnimation(runFrames, fps: 12);
      visual.setStateTint(null);
    } catch (_) {
      paint.color = const Color(0xFF36E1FF);
    }
  }

  @override
  void update(double dt) {
    final enemyDt = isMounted ? game.clock.enemyDt : dt;
    if (enemyDt <= 0) {
      super.update(dt);
      return;
    }
    _previousPosition.setFrom(position);
    stateTimer -= enemyDt;
    final target = targetPosition?.call() ?? game.world.player.position;
    switch (state) {
      case PhaseHoundState.stalk:
        _updateStalk(target, enemyDt);
        if (stateTimer <= 0 && position.distanceTo(target) <= 360) {
          _enterTelegraph(target);
        }
      case PhaseHoundState.telegraph:
        _visual?.setStateTint(
          (stateTimer * 14).floor().isEven ? null : const Color(0xFFFFB6F0),
        );
        if (stateTimer <= 0) _enterDash();
      case PhaseHoundState.dash:
        position += _lockedDirection * (dashSpeed * enemyDt);
        _trackDashApproach(target, _previousPosition, position);
        if (isMounted &&
            _dashClosestApproach <= dashHitRadius &&
            claimDashHit()) {
          game.world.player.takeDamage(1, causeId: 'enemy.phase_hound.dash');
        }
        _visual?.setStateTint(const Color(0xFFFFFFFF));
        if (stateTimer <= 0) _enterRecovery();
      case PhaseHoundState.recovery:
        _visual?.setStateTint(const Color(0xFF7E7394));
        if (stateTimer <= 0) {
          state = PhaseHoundState.stalk;
          stateTimer = stalkSeconds;
          _visual?.setStateTint(null);
          _setStateCue(null, const Color(0x00000000));
        }
    }
    super.update(dt);
  }

  void _updateStalk(Vector2 target, double dt) {
    final delta = target - position;
    final distance = delta.length;
    if (distance <= 1) return;
    final direction = delta / distance;
    final radial = distance > 210
        ? 1.0
        : distance < 145
        ? -0.65
        : 0.15;
    final sideSign = entityId.hashCode.isEven ? 1.0 : -1.0;
    final tangent = Vector2(-direction.y, direction.x) * sideSign;
    final steering = direction * radial + tangent * 0.48;
    if (steering.length2 > 1) steering.normalize();
    if (isMounted) {
      steering.add(
        game.world.survivalCrowdSteering(
          entityId: entityId,
          position: position,
          separationRadius: 62,
        ),
      );
      if (steering.length2 > 1) steering.normalize();
    }
    position += steering * (stalkSpeed * dt);
    _visual?.faceMovement(steering);
  }

  void _enterTelegraph(Vector2 target) {
    final delta = target - position;
    _lockedDirection = delta.length2 == 0 ? Vector2(1, 0) : delta.normalized();
    state = PhaseHoundState.telegraph;
    stateTimer = telegraphSeconds;
    scale.setAll(1.08);
    _setStateCue(
      _localizedCue('enemy.phaseHound.lock', 'LOCK'),
      const Color(0xFF36E1FF),
    );
  }

  void _enterDash() {
    state = PhaseHoundState.dash;
    stateTimer = dashSeconds;
    _dashHitClaimed = false;
    _dodgeReported = false;
    _dashClosestApproach = double.infinity;
    scale.setAll(1.18);
    _setStateCue(null, const Color(0x00000000));
  }

  void _enterRecovery({bool allowPerfectDodge = true}) {
    if (allowPerfectDodge &&
        !_dashHitClaimed &&
        !_dodgeReported &&
        _dashClosestApproach > dashHitRadius &&
        _dashClosestApproach <= perfectDodgeRadius) {
      _dodgeReported = true;
      onPerfectDodge?.call();
    }
    state = PhaseHoundState.recovery;
    stateTimer = recoverySeconds;
    scale.setAll(1);
    _setStateCue(
      _localizedCue('enemy.phaseHound.break', 'BREAK +1'),
      const Color(0xFF45F3A6),
    );
  }

  String _localizedCue(String key, String fallback) {
    if (!isMounted) return fallback;
    final localized = game.localization.text(key);
    return localized.startsWith('[') ? fallback : localized;
  }

  void _setStateCue(String? text, Color color) {
    _stateCue = text;
    final previous = _stateLabel;
    if (previous != null && previous.isMounted) previous.removeFromParent();
    _stateLabel = null;
    if (text == null || !isLoaded || isRemoving) return;
    final placeBelow = position.y < 100;
    final label = TextComponent(
      text: text,
      position: Vector2(width / 2, placeBelow ? height + 8 : -12),
      anchor: placeBelow ? Anchor.topCenter : Anchor.bottomCenter,
      priority: 40,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
    _stateLabel = label;
    add(label);
  }

  void _trackDashApproach(Vector2 target, Vector2 start, Vector2 end) {
    _dashClosestApproach = math.min(
      _dashClosestApproach,
      distanceToDashPath(target: target, start: start, end: end),
    );
  }

  static double distanceToDashPath({
    required Vector2 target,
    required Vector2 start,
    required Vector2 end,
  }) {
    final segment = end - start;
    if (segment.length2 == 0) return target.distanceTo(start);
    final offset = target - start;
    final projection = (offset.dot(segment) / segment.length2).clamp(0.0, 1.0);
    return target.distanceTo(start + segment * projection);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is WallComponent ||
        (other is PhaseWallComponent && other.isSolid)) {
      position.setFrom(_previousPosition);
      if (state == PhaseHoundState.dash) {
        _enterRecovery(allowPerfectDodge: false);
      }
    } else if (other is PlayerComponent && claimDashHit()) {
      other.takeDamage(1, causeId: 'enemy.phase_hound.dash');
    }
    super.onCollision(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(width / 2, height / 2);
    final ringColor = state == PhaseHoundState.recovery
        ? const Color(0x887E7394)
        : const Color(0xCC36E1FF);
    canvas.drawCircle(
      center,
      24 + math.sin(stateTimer * 12).abs() * 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = state == PhaseHoundState.telegraph ? 3 : 1.5
        ..color = ringColor,
    );
    if (state == PhaseHoundState.telegraph) {
      final progress = (1 - stateTimer / telegraphSeconds).clamp(0.0, 1.0);
      final target =
          center + Offset(_lockedDirection.x, _lockedDirection.y) * 900;
      canvas.drawLine(
        center,
        target,
        Paint()
          ..strokeWidth = 1.5 + progress * 3
          ..color = Color.fromRGBO(54, 225, 255, 0.3 + progress * 0.6),
      );
    }
    if (state == PhaseHoundState.dash) {
      final trail = Offset(-_lockedDirection.x, -_lockedDirection.y);
      for (var index = 1; index <= 3; index += 1) {
        canvas.drawCircle(
          center + trail * (index * 12),
          12 - index * 2,
          Paint()..color = Color.fromRGBO(54, 225, 255, 0.22 / index),
        );
      }
    }
    final ratio = healthState.current / healthState.max;
    canvas.drawRect(
      Rect.fromLTWH(3, -7, 32, 3),
      Paint()..color = const Color(0xFF25304A),
    );
    canvas.drawRect(
      Rect.fromLTWH(3, -7, 32 * ratio, 3),
      Paint()..color = const Color(0xFF36E1FF),
    );
    super.render(canvas);
  }

  @override
  void receiveDamage(int amount) {
    if (amount <= 0 || _defeatReported) return;
    final defeatedDuringBreak = state == PhaseHoundState.recovery;
    final effectiveAmount =
        amount + (defeatedDuringBreak ? recoveryDamageBonus : 0);
    if (healthState.applyDamage(effectiveAmount) == HealthMutation.defeated) {
      _defeatReported = true;
      if (isMounted) {
        game.world.spawnDataShards(
          position,
          count: 3,
          alternatingCorruption: false,
        );
      }
      onDefeated();
      if (defeatedDuringBreak) onBreakDefeated?.call(_dodgeReported);
      removeFromParent();
    } else {
      _visual?.flash(const Color(0xFFFFFFFF));
      _visual?.squash();
    }
  }

  @override
  void receiveHealing(int amount) => healthState.applyHealing(amount);
}
