import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class PlayerComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  PlayerComponent({required super.position, required this.spawnPosition})
    : super(
        size: Vector2.all(32),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFF36E1FF),
        priority: 20,
      );

  static const double moveSpeed = 160;
  static const double attackCooldownSeconds = 0.45;
  static const double hitInvulnerabilitySeconds = 0.70;

  final Vector2 spawnPosition;
  final Vector2 _movementInput = Vector2.zero();
  final Vector2 _previousPosition = Vector2.zero();

  int maxIntegrity = 5;
  int integrity = 5;

  double _attackCooldown = 0;
  double _hitInvulnerability = 0;
  String? lastDamageCauseId;

  bool get canAttack => _attackCooldown <= 0 && !isRemoving;
  bool get isInvulnerable => _hitInvulnerability > 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RectangleHitbox.relative(
        Vector2.all(0.66),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  void setMovementInput(Vector2 input) {
    _movementInput.setFrom(input);
  }

  void tryAttack() {
    if (!canAttack) {
      return;
    }

    _attackCooldown = attackCooldownSeconds;
    final pulsePosition = position.clone();
    game.world.spawnPatchPulse(pulsePosition);
    game.patchEffects.onPatchPulseEmitted(pulsePosition);
  }

  void tryInteract() {
    game.world.tryInteract(this);
  }

  void takeDamage(int amount, {String causeId = 'unknown'}) {
    if (amount <= 0 || isInvulnerable || integrity <= 0) {
      return;
    }

    integrity = math.max(0, integrity - amount);
    lastDamageCauseId = causeId;
    _hitInvulnerability = hitInvulnerabilitySeconds;
    if (isMounted) {
      game.publishUiSnapshot();
    }
    if (integrity == 0) {
      game.requestRoomRestart(causeId: causeId);
    }
  }

  @override
  void update(double dt) {
    final statusDt = isMounted ? game.clock.playerStatusDt : dt;
    final simulationDt = isMounted ? game.clock.simulationDt : dt;
    _attackCooldown = math.max(0, _attackCooldown - simulationDt);
    _hitInvulnerability = math.max(0, _hitInvulnerability - statusDt);

    _previousPosition.setFrom(position);
    position += _movementInput * (moveSpeed * statusDt);
    _clampToLogicalWorld();
    _updateDamageBlink();
    super.update(dt);
  }

  void _clampToLogicalWorld() {
    final halfWidth = size.x / 2;
    final halfHeight = size.y / 2;
    position.x = position.x
        .clamp(halfWidth, PatchWorldGame.logicalWidth - halfWidth)
        .toDouble();
    position.y = position.y
        .clamp(halfHeight, PatchWorldGame.logicalHeight - halfHeight)
        .toDouble();
  }

  void _updateDamageBlink() {
    if (!isInvulnerable) {
      paint.color = const Color(0xFF36E1FF);
      return;
    }

    final visible = (_hitInvulnerability * 12).floor().isEven;
    paint.color = visible ? const Color(0xFF36E1FF) : const Color(0x5536E1FF);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is WallComponent) {
      position.setFrom(_previousPosition);
    }
    super.onCollision(intersectionPoints, other);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is CrawlerComponent) {
      takeDamage(1, causeId: 'enemy.crawler.contact');
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
