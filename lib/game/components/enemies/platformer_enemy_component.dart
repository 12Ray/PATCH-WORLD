import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/systems/combat_system.dart';

enum PlatformerEnemyMobility { grounded, hopper, flying, turret, boss }

enum PlatformerEnemyArchetype {
  patchMite,
  checksumHopper,
  pulseTurret,
  repairLeech,
  overflowWarden,
  tickRunner,
  echoBat,
  delaySniper,
  rewindSkater,
  chronoJailer,
  vectorRam,
  polarityDrone,
  phaseMimic,
  shardLobber,
  kernelChimera,
}

extension PlatformerEnemyArchetypeSpec on PlatformerEnemyArchetype {
  String get displayName => switch (this) {
    PlatformerEnemyArchetype.patchMite => 'PATCH MITE',
    PlatformerEnemyArchetype.checksumHopper => 'CHECKSUM HOPPER',
    PlatformerEnemyArchetype.pulseTurret => 'PULSE TURRET',
    PlatformerEnemyArchetype.repairLeech => 'REPAIR LEECH',
    PlatformerEnemyArchetype.overflowWarden => 'OVERFLOW WARDEN',
    PlatformerEnemyArchetype.tickRunner => 'TICK RUNNER',
    PlatformerEnemyArchetype.echoBat => 'ECHO BAT',
    PlatformerEnemyArchetype.delaySniper => 'DELAY SNIPER',
    PlatformerEnemyArchetype.rewindSkater => 'REWIND SKATER',
    PlatformerEnemyArchetype.chronoJailer => 'CHRONO JAILER',
    PlatformerEnemyArchetype.vectorRam => 'VECTOR RAM',
    PlatformerEnemyArchetype.polarityDrone => 'POLARITY DRONE',
    PlatformerEnemyArchetype.phaseMimic => 'PHASE MIMIC',
    PlatformerEnemyArchetype.shardLobber => 'SHARD LOBBER',
    PlatformerEnemyArchetype.kernelChimera => 'KERNEL CHIMERA',
  };

  PlatformerEnemyMobility get mobility => switch (this) {
    PlatformerEnemyArchetype.checksumHopper => PlatformerEnemyMobility.hopper,
    PlatformerEnemyArchetype.echoBat ||
    PlatformerEnemyArchetype.polarityDrone => PlatformerEnemyMobility.flying,
    PlatformerEnemyArchetype.chronoJailer => PlatformerEnemyMobility.flying,
    PlatformerEnemyArchetype.pulseTurret ||
    PlatformerEnemyArchetype.delaySniper ||
    PlatformerEnemyArchetype.phaseMimic ||
    PlatformerEnemyArchetype.shardLobber => PlatformerEnemyMobility.turret,
    PlatformerEnemyArchetype.overflowWarden ||
    PlatformerEnemyArchetype.kernelChimera => PlatformerEnemyMobility.boss,
    _ => PlatformerEnemyMobility.grounded,
  };

  bool get isMidBoss => switch (this) {
    PlatformerEnemyArchetype.overflowWarden ||
    PlatformerEnemyArchetype.chronoJailer ||
    PlatformerEnemyArchetype.kernelChimera => true,
    _ => false,
  };

  Color get primaryColor => switch (index ~/ 5) {
    0 => const Color(0xFFB52E45),
    1 => const Color(0xFF4359C7),
    _ => const Color(0xFF167F92),
  };

  Color get accentColor => switch (index ~/ 5) {
    0 => const Color(0xFFFF4FD8),
    1 => const Color(0xFF9D8CFF),
    _ => index.isEven ? const Color(0xFF36E1FF) : const Color(0xFFFF4FD8),
  };
}

final class PlatformerEnemyComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  PlatformerEnemyComponent({
    required this.archetype,
    required super.position,
    required this.onDefeated,
  }) : healthState = HealthState(
         max: archetype.isMidBoss ? 8 : 3,
         current: archetype.index < 5
             ? (archetype.isMidBoss ? 7 : 2)
             : (archetype.isMidBoss ? 8 : 3),
       ),
       super(
         size: archetype.isMidBoss ? Vector2(58, 62) : Vector2(38, 36),
         anchor: Anchor.center,
         priority: 12,
       );

  final PlatformerEnemyArchetype archetype;
  final HealthState healthState;
  final void Function(PlatformerEnemyComponent enemy) onDefeated;
  final Vector2 _velocity = Vector2.zero();
  late final Vector2 _homePosition;

  double _jumpCooldown = 0;
  double _actionClock = 0;
  double _nextAttackAt = 1.4;
  double _nextSupportAt = 2.2;
  double _overflowTimer = 0;
  bool _grounded = false;
  bool _resolved = false;

  @override
  String get entityId => 'platformer.${archetype.name}';

  int get health => healthState.current;
  bool get isOverflowing => _overflowTimer > 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _homePosition = position.clone();
    await add(
      RectangleHitbox.relative(
        archetype.isMidBoss ? Vector2(0.78, 0.86) : Vector2(0.76, 0.78),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
    await add(
      TextComponent(
        text: archetype.displayName,
        position: Vector2(size.x / 2, -10),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: TextStyle(
            color: archetype.accentColor,
            fontSize: archetype.isMidBoss ? 9 : 7,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  void receiveDamage(int amount) {
    if (_resolved || amount <= 0) return;
    final mutation = healthState.applyDamage(amount);
    if (mutation == HealthMutation.defeated) _resolveDefeat();
  }

  @override
  void receiveHealing(int amount) {
    if (_resolved || amount <= 0) return;
    final mutation = healthState.applyHealing(amount);
    if (mutation == HealthMutation.overflowed) _overflowTimer = 0.36;
  }

  @override
  void update(double dt) {
    final simulationDt = game.clock.simulationDt;
    if (_overflowTimer > 0) {
      _overflowTimer -= simulationDt;
      scale.setAll(1 + (0.36 - _overflowTimer) * 0.7);
      if (_overflowTimer <= 0) _resolveDefeat(corrupted: true);
      super.update(dt);
      return;
    }
    if (!game.world.isReady || _resolved) {
      super.update(dt);
      return;
    }

    final enemyDt = game.clock.enemyDt;
    if (enemyDt <= 0) {
      super.update(dt);
      return;
    }
    _actionClock += enemyDt;
    _jumpCooldown = math.max(0, _jumpCooldown - enemyDt);
    final activeRoom = game.world.activeRoom;
    final room = activeRoom is PlatformerRoomGeometry
        ? activeRoom as PlatformerRoomGeometry
        : null;
    if (room == null) {
      super.update(dt);
      return;
    }

    switch (archetype.mobility) {
      case PlatformerEnemyMobility.flying:
        _updateFlying(enemyDt);
      case PlatformerEnemyMobility.turret:
        _updateTurret(enemyDt, room.solidBounds);
      case PlatformerEnemyMobility.grounded ||
          PlatformerEnemyMobility.hopper ||
          PlatformerEnemyMobility.boss:
        _updateGrounded(enemyDt, room.solidBounds);
    }
    _updateConceptAction();
    super.update(dt);
  }

  void _updateConceptAction() {
    final firesProjectile = switch (archetype) {
      PlatformerEnemyArchetype.pulseTurret ||
      PlatformerEnemyArchetype.delaySniper ||
      PlatformerEnemyArchetype.shardLobber ||
      PlatformerEnemyArchetype.polarityDrone ||
      PlatformerEnemyArchetype.chronoJailer => true,
      _ => false,
    };
    if (firesProjectile && _actionClock >= _nextAttackAt) {
      _nextAttackAt = _actionClock + (archetype.isMidBoss ? 1.35 : 2.2);
      unawaited(_fireAtPlayer());
    }
    if (archetype == PlatformerEnemyArchetype.repairLeech &&
        _actionClock >= _nextSupportAt) {
      _nextSupportAt = _actionClock + 2.8;
      _repairNearestAlly();
    }
  }

  Future<void> _fireAtPlayer() async {
    if (!game.world.canSpawnProjectile || isRemoving) return;
    final direction = game.world.player.position - position;
    if (direction.length2 == 0) direction.x = 1;
    direction.normalize();
    await parent?.add(
      EnemyProjectileComponent(
        position: position.clone(),
        velocity: direction * (archetype.isMidBoss ? 145 : 120),
      ),
    );
  }

  void _repairNearestAlly() {
    PlatformerEnemyComponent? nearest;
    var nearestDistance = double.infinity;
    for (final target in game.world.activeCombatTargets) {
      if (target is! PlatformerEnemyComponent ||
          identical(target, this) ||
          target._resolved) {
        continue;
      }
      final distance = position.distanceToSquared(target.position);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = target;
      }
    }
    if (nearestDistance <= 230 * 230) nearest?.receiveHealing(1);
  }

  void _updateFlying(double dt) {
    final player = game.world.player.position;
    final target = Vector2(
      player.x,
      player.y - 64 + math.sin(_actionClock * 3) * 18,
    );
    final delta = target - position;
    final speed = archetype.isMidBoss ? 62.0 : 78.0;
    if (delta.length2 > 26 * 26) {
      delta.normalize();
      position += delta * speed * dt;
    }
    position.x = position.x.clamp(36, PatchWorldGame.logicalWidth - 36);
    position.y = position.y.clamp(100, 440);
  }

  void _updateTurret(double dt, Iterable<Rect> solids) {
    final pulse = 1 + math.sin(_actionClock * 4).abs() * 0.05;
    scale.setAll(pulse);
    _velocity.y = math.min(620, _velocity.y + 1100 * dt);
    _moveVertical(dt, solids);
  }

  void _updateGrounded(double dt, Iterable<Rect> solids) {
    final player = game.world.player.position;
    final playerDistanceX = (player.x - position.x).abs();
    final aggroRange = archetype.isMidBoss ? 220.0 : 120.0;
    final patrolTarget = _homePosition.x + math.sin(_actionClock * 0.8) * 46;
    final targetX = playerDistanceX <= aggroRange ? player.x : patrolTarget;
    final direction = (targetX - position.x).sign.toDouble();
    var speed = archetype.isMidBoss ? 52.0 : 66.0;
    if (archetype == PlatformerEnemyArchetype.tickRunner) speed = 88;
    if (archetype == PlatformerEnemyArchetype.rewindSkater ||
        archetype == PlatformerEnemyArchetype.vectorRam) {
      speed *= 1 + (math.sin(_actionClock * 2.2) > 0.55 ? 1.5 : 0);
    }
    _velocity.x = direction * speed;
    final shouldJump =
        archetype.mobility == PlatformerEnemyMobility.hopper ||
        (_grounded && !_hasSupportAhead(solids, direction)) ||
        (player.y < position.y - 42 &&
            archetype.mobility != PlatformerEnemyMobility.grounded);
    if (_grounded && _jumpCooldown <= 0 && shouldJump) {
      _velocity.y = archetype.isMidBoss ? -420 : -385;
      _grounded = false;
      _jumpCooldown = archetype.mobility == PlatformerEnemyMobility.hopper
          ? 1.15
          : 1.8;
    }
    _velocity.y = math.min(620, _velocity.y + 1100 * dt);

    final oldX = position.x;
    position.x += _velocity.x * dt;
    _resolveHorizontal(solids, oldX);
    _moveVertical(dt, solids);
  }

  bool _hasSupportAhead(Iterable<Rect> solids, double direction) {
    final probeX = position.x + direction * (size.x / 2 + 10);
    final probeY = position.y + size.y / 2 + 6;
    return solids.any(
      (solid) =>
          probeX >= solid.left &&
          probeX <= solid.right &&
          probeY >= solid.top &&
          probeY <= solid.bottom,
    );
  }

  void _moveVertical(double dt, Iterable<Rect> solids) {
    final oldY = position.y;
    _grounded = false;
    position.y += _velocity.y * dt;
    _resolveVertical(solids, oldY);
    if (position.y > PatchWorldGame.logicalHeight + 80) {
      position.setFrom(_homePosition);
      _velocity.setZero();
      _grounded = false;
      _jumpCooldown = 0.35;
    }
  }

  void _resolveHorizontal(Iterable<Rect> solids, double oldX) {
    final halfWidth = size.x / 2;
    final oldLeft = oldX - halfWidth;
    final oldRight = oldX + halfWidth;
    for (final solid in solids) {
      if (!_bounds.overlaps(solid)) continue;
      if (_velocity.x > 0 && oldRight <= solid.left + 1) {
        position.x = solid.left - halfWidth;
        _velocity.x = 0;
      } else if (_velocity.x < 0 && oldLeft >= solid.right - 1) {
        position.x = solid.right + halfWidth;
        _velocity.x = 0;
      }
    }
  }

  void _resolveVertical(Iterable<Rect> solids, double oldY) {
    final halfHeight = size.y / 2;
    final oldTop = oldY - halfHeight;
    final oldBottom = oldY + halfHeight;
    for (final solid in solids) {
      if (!_bounds.overlaps(solid)) continue;
      if (_velocity.y >= 0 && oldBottom <= solid.top + 1) {
        position.y = solid.top - halfHeight;
        _velocity.y = 0;
        _grounded = true;
      } else if (_velocity.y < 0 && oldTop >= solid.bottom - 1) {
        position.y = solid.bottom + halfHeight;
        _velocity.y = 0;
      }
    }
  }

  Rect get _bounds => Rect.fromCenter(
    center: Offset(position.x, position.y),
    width: size.x,
    height: size.y,
  );

  void _resolveDefeat({bool corrupted = false}) {
    if (_resolved) return;
    _resolved = true;
    if (isMounted) {
      game.world.spawnDataShards(
        position,
        count: archetype.isMidBoss ? 5 : 2,
        corrupted: corrupted,
      );
    }
    onDefeated(this);
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final primary = Paint()..color = archetype.primaryColor;
    final accent = Paint()..color = archetype.accentColor;
    final dark = Paint()..color = const Color(0xFF101827);
    final center = Offset(size.x / 2, size.y / 2);
    final body = Rect.fromCenter(
      center: center,
      width: archetype.isMidBoss ? size.x * 0.72 : size.x * 0.64,
      height: archetype.isMidBoss ? size.y * 0.66 : size.y * 0.52,
    );

    canvas.drawRect(body, primary);
    switch (archetype) {
      case PlatformerEnemyArchetype.patchMite:
        for (final y in <double>[20, 27, 34]) {
          canvas.drawLine(
            Offset(8, y),
            Offset(1, y + 4),
            accent..strokeWidth = 2,
          );
          canvas.drawLine(Offset(30, y), Offset(37, y + 4), accent);
        }
        canvas.drawRect(const Rect.fromLTWH(26, 15, 7, 7), accent);
      case PlatformerEnemyArchetype.checksumHopper:
        canvas.drawLine(
          const Offset(19, 23),
          const Offset(10, 35),
          accent..strokeWidth = 3,
        );
        canvas.drawLine(const Offset(10, 35), const Offset(28, 35), accent);
        canvas.drawLine(const Offset(28, 35), const Offset(19, 23), accent);
      case PlatformerEnemyArchetype.pulseTurret:
        canvas.drawRect(const Rect.fromLTWH(19, 12, 19, 7), accent);
        canvas.drawCircle(const Offset(19, 19), 5, dark);
      case PlatformerEnemyArchetype.repairLeech:
        canvas.drawLine(
          const Offset(4, 26),
          const Offset(34, 12),
          accent..strokeWidth = 5,
        );
        canvas.drawCircle(const Offset(32, 12), 5, dark);
      case PlatformerEnemyArchetype.overflowWarden:
        canvas.drawRect(const Rect.fromLTWH(8, 12, 15, 34), accent);
        canvas.drawRect(const Rect.fromLTWH(38, 15, 15, 38), dark);
        canvas.drawCircle(const Offset(29, 28), 8, accent);
      case PlatformerEnemyArchetype.tickRunner:
        canvas.drawLine(
          const Offset(19, 20),
          const Offset(19, 35),
          accent..strokeWidth = 3,
        );
        canvas.drawCircle(const Offset(19, 34), 4, accent);
      case PlatformerEnemyArchetype.echoBat:
        final wings = Path()
          ..moveTo(19, 18)
          ..lineTo(1, 8)
          ..lineTo(7, 29)
          ..lineTo(19, 23)
          ..lineTo(31, 29)
          ..lineTo(37, 8)
          ..close();
        canvas.drawPath(wings, accent);
      case PlatformerEnemyArchetype.delaySniper:
        canvas.drawRect(const Rect.fromLTWH(17, 3, 5, 25), accent);
        canvas.drawLine(
          const Offset(19, 25),
          const Offset(5, 36),
          accent..strokeWidth = 2,
        );
        canvas.drawLine(const Offset(19, 25), const Offset(33, 36), accent);
      case PlatformerEnemyArchetype.rewindSkater:
        canvas.drawCircle(const Offset(19, 31), 7, dark);
        canvas.drawCircle(const Offset(19, 31), 3, accent);
        canvas.drawLine(
          const Offset(4, 11),
          const Offset(34, 11),
          accent..strokeWidth = 2,
        );
      case PlatformerEnemyArchetype.chronoJailer:
        canvas.drawCircle(
          center,
          19,
          accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        canvas.drawLine(center, const Offset(29, 6), accent);
        canvas.drawLine(center, const Offset(51, 31), accent);
      case PlatformerEnemyArchetype.vectorRam:
        final wedge = Path()
          ..moveTo(3, 28)
          ..lineTo(34, 8)
          ..lineTo(34, 32)
          ..close();
        canvas.drawPath(wedge, accent);
      case PlatformerEnemyArchetype.polarityDrone:
        canvas.drawCircle(const Offset(13, 18), 10, accent);
        canvas.drawCircle(const Offset(25, 18), 10, dark);
        canvas.drawLine(
          const Offset(19, 5),
          const Offset(19, 31),
          primary..strokeWidth = 3,
        );
      case PlatformerEnemyArchetype.phaseMimic:
        canvas.drawRect(
          const Rect.fromLTWH(5, 5, 28, 28),
          accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        canvas.drawLine(const Offset(8, 25), const Offset(30, 25), accent);
      case PlatformerEnemyArchetype.shardLobber:
        for (final x in <double>[9, 19, 29]) {
          final shard = Path()
            ..moveTo(x, 5)
            ..lineTo(x - 5, 16)
            ..lineTo(x + 5, 16)
            ..close();
          canvas.drawPath(shard, accent);
        }
      case PlatformerEnemyArchetype.kernelChimera:
        canvas.drawRect(const Rect.fromLTWH(4, 15, 22, 33), accent);
        canvas.drawRect(const Rect.fromLTWH(32, 15, 22, 33), dark);
        canvas.drawCircle(
          const Offset(29, 30),
          9,
          Paint()..color = const Color(0xFFFFFFFF),
        );
    }

    final maxRatio = healthState.max / healthState.overflowThreshold;
    final currentRatio = healthState.normalizedForOverflowBar;
    canvas.drawRect(
      Rect.fromLTWH(0, -5, size.x, 3),
      dark..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -5, size.x * math.min(currentRatio, maxRatio), 3),
      Paint()..color = const Color(0xFF36E1FF),
    );
    if (currentRatio > maxRatio) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.x * maxRatio,
          -5,
          size.x * (currentRatio - maxRatio),
          3,
        ),
        Paint()..color = const Color(0xFFFF4FD8),
      );
    }
  }
}
