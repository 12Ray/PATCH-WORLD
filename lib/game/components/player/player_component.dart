import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/game_settings.dart';

final class PlayerComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  PlayerComponent({required super.position, required this.spawnPosition})
    : super(
        size: Vector2.all(32),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x00000000),
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
  int _dataShardCharge = 0;
  EntitySpriteVisual? _visual;
  List<Sprite>? _pulseFrames;
  String? lastDamageCauseId;

  bool get canAttack => _attackCooldown <= 0 && !isRemoving;
  bool get isInvulnerable => _hitInvulnerability > 0;
  int get dataShardCharge => _dataShardCharge;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    unawaited(_loadVisual());
    await add(
      RectangleHitbox.relative(
        Vector2.all(0.66),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  Future<void> _loadVisual() async {
    try {
      final visual = EntitySpriteVisual(
        sprite: await game.loadSprite('sprites/qa-hero.png'),
        size: Vector2.all(54),
        parentSize: size,
        bobAmplitude: 1.1,
        bobSpeed: 4.2,
      );
      if (isRemoving) return;
      _visual = visual;
      await add(visual);
      await _loadAnimations(visual);
    } catch (_) {
      paint.color = const Color(0xFF36E1FF);
    }
  }

  Future<void> _loadAnimations(EntitySpriteVisual visual) async {
    final idleImage = await game.images.load(
      'sprites/animations/qa-hero-idle.png',
    );
    final pulseImage = await game.images.load(
      'sprites/animations/qa-hero-pulse.png',
    );
    if (isRemoving) return;
    visual.setDefaultAnimation(_frames(idleImage, 4), fps: 6);
    _pulseFrames = _frames(pulseImage, 4);
  }

  List<Sprite> _frames(Image image, int count) => List.generate(
    count,
    (index) => Sprite(
      image,
      srcPosition: Vector2(index * 256.0, 0),
      srcSize: Vector2.all(256),
    ),
  );

  void setMovementInput(Vector2 input) {
    _movementInput.setFrom(input);
  }

  void tryAttack() {
    if (!canAttack) {
      return;
    }

    _attackCooldown = attackCooldownSeconds;
    final pulseFrames = _pulseFrames;
    if (pulseFrames != null) {
      _visual?.playOnce(pulseFrames, fps: 10);
    }
    _visual?.flash(const Color(0xFFFF8FE8), seconds: 0.10);
    _visual?.squash();
    final pulsePosition = position.clone();
    game.world.spawnPatchPulse(pulsePosition);
    game.patchEffects.onPatchPulseEmitted(pulsePosition);
    unawaited(game.audio.playPatchPulse());
  }

  void tryInteract() {
    game.world.tryInteract(this);
  }

  void takeDamage(int amount, {String causeId = 'unknown'}) {
    if (amount <= 0 || isInvulnerable || integrity <= 0) {
      return;
    }

    final appliedDamage = math.min(integrity, amount);
    integrity = math.max(0, integrity - amount);
    if (isMounted) game.runMetrics.recordDamage(appliedDamage);
    if (isMounted) {
      unawaited(game.audio.playDamage());
      game.triggerImpactFeedback();
    }
    lastDamageCauseId = causeId;
    _hitInvulnerability = hitInvulnerabilitySeconds;
    _visual?.flash(const Color(0xFFFF6464), seconds: 0.18);
    _visual?.squash(seconds: 0.20);
    if (isMounted) {
      game.publishUiSnapshot();
    }
    if (integrity == 0) {
      game.handlePlayerDefeat(causeId: causeId);
    }
  }

  void absorbDataShard() {
    _dataShardCharge += 1;
    _attackCooldown = math.max(0, _attackCooldown - 0.08);
    _visual?.flash(const Color(0xFF36E1FF), seconds: 0.08);
    if (_dataShardCharge < 6) return;

    _dataShardCharge = 0;
    _attackCooldown = 0;
    if (integrity < maxIntegrity) integrity += 1;
    if (isMounted) {
      unawaited(game.audio.playHeal());
      game.publishUiSnapshot(force: true);
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
    _visual?.faceMovement(_movementInput);
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
      _visual?.setVisualOpacity(1);
      return;
    }

    if (isMounted && game.settings.value.flash == FlashSetting.reduced) {
      _visual?.setVisualOpacity(0.72);
      return;
    }

    final visible = (_hitInvulnerability * 12).floor().isEven;
    _visual?.setVisualOpacity(visible ? 1 : 0.32);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is WallComponent ||
        (other is PhaseWallComponent && other.isSolid)) {
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_dataShardCharge == 0) return;
    for (var index = 0; index < 6; index += 1) {
      final active = index < _dataShardCharge;
      canvas.drawRect(
        Rect.fromLTWH(2 + index * 5, -9, 3, 3),
        Paint()
          ..color = active ? const Color(0xFF36E1FF) : const Color(0x4425304A),
      );
    }
  }
}
