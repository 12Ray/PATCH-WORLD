import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/components/effects/enemy_damage_volume_component.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_action_timeline.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_combat_state.dart';
import 'package:patch_world/game/components/enemies/platformer/platformer_enemy_brain.dart';
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
  String get assetSlug => name
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}-${m[2]}')
      .toLowerCase();
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
  double _overflowTimer = 0;
  bool _grounded = false;
  bool _resolved = false;
  double _facing = 1;
  EnemyActionTimeline? _action;
  EnemyCombatState _combatState = EnemyCombatState.idle;
  bool _hopperLandingPending = false;
  bool _wardenSummonedAtHighThreshold = false;
  bool _wardenSummonedAtLowThreshold = false;
  int _wardenPatternIndex = 0;
  bool _rewindReturning = false;
  bool _polarityPushes = false;
  SpriteComponent? _spriteVisual;
  List<Sprite>? _spriteFrames;
  final List<Vector2> _motionHistory = <Vector2>[];

  @override
  String get entityId => 'platformer.${archetype.name}';

  int get health => healthState.current;
  bool get isOverflowing => _overflowTimer > 0;
  EnemyCombatState get combatState => _combatState;
  String? get activeActionId => _action?.id;
  bool get dealsContactDamage => false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _homePosition = position.clone();
    unawaited(_loadSpriteVisual());
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

  Future<void> _loadSpriteVisual() async {
    try {
      final image = await game.images.load(
        'sprites/platformer/${archetype.assetSlug}.png',
      );
      if (isRemoving) return;
      final frames = List<Sprite>.generate(
        4,
        (index) => Sprite(
          image,
          srcPosition: Vector2(index * 256.0, 0),
          srcSize: Vector2.all(256),
        ),
      );
      final visual = SpriteComponent(
        sprite: frames.first,
        size: Vector2.all(archetype.isMidBoss ? 104 : 70),
        position: size / 2,
        anchor: Anchor.center,
        priority: 4,
      )..paint.filterQuality = FilterQuality.none;
      _spriteFrames = frames;
      _spriteVisual = visual;
      await add(visual);
    } catch (_) {
      // Procedural proxy remains available during development.
    }
  }

  @override
  void receiveDamage(int amount) {
    if (_resolved || amount <= 0) return;
    final mutation = healthState.applyDamage(amount);
    if (mutation == HealthMutation.defeated) {
      _resolveDefeat();
    } else {
      _combatState = EnemyCombatState.hurt;
    }
  }

  @override
  void receiveHealing(int amount) {
    if (_resolved || amount <= 0) return;
    if (_isWardenGuardBlockingPlayer) return;
    _applyHealing(amount);
  }

  void _receiveSupportHealing(int amount) {
    if (_resolved || amount <= 0) return;
    _applyHealing(amount);
  }

  void _applyHealing(int amount) {
    final mutation = healthState.applyHealing(amount);
    if (mutation == HealthMutation.overflowed) _overflowTimer = 0.36;
  }

  bool get _isWardenGuardBlockingPlayer {
    if (archetype != PlatformerEnemyArchetype.overflowWarden ||
        _action?.id != 'warden.guard' ||
        _action?.phase != EnemyActionPhase.active ||
        !isMounted) {
      return false;
    }
    final playerDelta = game.world.player.position.x - position.x;
    return playerDelta.sign == _facing.sign;
  }

  @override
  void update(double dt) {
    final simulationDt = game.clock.simulationDt;
    if (_overflowTimer > 0) {
      _combatState = EnemyCombatState.overflowing;
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

    if (archetype.index < 5) {
      _scheduleDamageLabAction();
    } else {
      _scheduleAdvancedRoomAction();
    }
    _advanceAction(enemyDt);

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
    _updateMotionHistory();
    if (_action == null && _combatState != EnemyCombatState.hurt) {
      _combatState = _velocity.length2 > 1
          ? EnemyCombatState.moving
          : EnemyCombatState.idle;
    } else if (_combatState == EnemyCombatState.hurt) {
      _combatState = EnemyCombatState.idle;
    }
    _syncSpriteVisual();
    super.update(dt);
  }

  void _updateMotionHistory() {
    if (archetype == PlatformerEnemyArchetype.echoBat ||
        archetype == PlatformerEnemyArchetype.chronoJailer) {
      _motionHistory.add(game.world.player.position.clone());
    } else if (archetype == PlatformerEnemyArchetype.rewindSkater) {
      if (_action?.id == 'rewindSkater.rewind' &&
          _action?.phase == EnemyActionPhase.active &&
          _motionHistory.isNotEmpty) {
        position.setFrom(_motionHistory.removeLast());
        return;
      }
      _motionHistory.add(position.clone());
    } else {
      return;
    }
    if (_motionHistory.length > 72) _motionHistory.removeAt(0);
  }

  void _syncSpriteVisual() {
    final visual = _spriteVisual;
    final frames = _spriteFrames;
    if (visual == null || frames == null) return;
    final frameIndex = switch (_combatState) {
      EnemyCombatState.idle => 0,
      EnemyCombatState.moving => 1,
      EnemyCombatState.telegraph ||
      EnemyCombatState.attacking ||
      EnemyCombatState.recovering => 2,
      EnemyCombatState.hurt ||
      EnemyCombatState.staggered ||
      EnemyCombatState.overflowing ||
      EnemyCombatState.defeated => 3,
    };
    visual.sprite = frames[frameIndex];
    visual.scale.x = _facing;
  }

  void _scheduleDamageLabAction() {
    if (_action != null || _actionClock < _nextAttackAt) return;
    final playerDistance = game.world.player.position.distanceTo(position);
    switch (archetype) {
      case PlatformerEnemyArchetype.patchMite:
        if (playerDistance <= 145) {
          _beginBrainAction();
        }
      case PlatformerEnemyArchetype.checksumHopper:
        if (_grounded && playerDistance <= 310) {
          _beginBrainAction();
        }
      case PlatformerEnemyArchetype.pulseTurret:
        if (playerDistance <= 520) {
          _beginBrainAction();
        }
      case PlatformerEnemyArchetype.repairLeech:
        _beginBrainAction();
      case PlatformerEnemyArchetype.overflowWarden:
        final shouldSummonHigh =
            healthState.current <= 5 && !_wardenSummonedAtHighThreshold;
        final shouldSummonLow =
            healthState.current <= 2 && !_wardenSummonedAtLowThreshold;
        if (shouldSummonHigh || shouldSummonLow) {
          if (shouldSummonHigh) {
            _wardenSummonedAtHighThreshold = true;
          } else {
            _wardenSummonedAtLowThreshold = true;
          }
          _beginBrainAction(variant: 'summon');
        } else if (_wardenPatternIndex.isEven) {
          _wardenPatternIndex += 1;
          _beginBrainAction();
        } else {
          _wardenPatternIndex += 1;
          _facing = (game.world.player.position.x - position.x).sign.toDouble();
          if (_facing == 0) _facing = 1;
          _beginBrainAction(variant: 'guard');
        }
      default:
        break;
    }
  }

  void _scheduleAdvancedRoomAction() {
    if (_action != null || _actionClock < _nextAttackAt) return;
    final variant = switch (archetype) {
      PlatformerEnemyArchetype.rewindSkater =>
        _rewindReturning ? 'rewind' : null,
      PlatformerEnemyArchetype.polarityDrone => _polarityPushes ? 'push' : null,
      _ => null,
    };
    _beginBrainAction(variant: variant);
  }

  void _beginAction({
    required String id,
    required double telegraph,
    required double active,
    required double recovery,
  }) {
    _action = EnemyActionTimeline(
      id: id,
      telegraphSeconds: telegraph,
      activeSeconds: active,
      recoverySeconds: recovery,
    );
    _combatState = EnemyCombatState.telegraph;
    final direction = game.world.player.position.x - position.x;
    if (direction.abs() > 0.01) _facing = direction.sign.toDouble();
  }

  void _beginBrainAction({String? variant}) {
    final decision = PlatformerEnemyBrain.forArchetype(
      archetype.name,
      variant: variant,
    );
    _beginAction(
      id: decision.actionId,
      telegraph: decision.telegraph,
      active: decision.active,
      recovery: decision.recovery,
    );
  }

  void _advanceAction(double dt) {
    final action = _action;
    if (action == null) return;
    final tick = action.advance(dt);
    _combatState = switch (action.phase) {
      EnemyActionPhase.telegraph => EnemyCombatState.telegraph,
      EnemyActionPhase.active => EnemyCombatState.attacking,
      EnemyActionPhase.recovery => EnemyCombatState.recovering,
      EnemyActionPhase.completed => EnemyCombatState.idle,
    };
    if (tick.enteredActive) _executeAction(action.id);
    if (tick.completed) {
      _action = null;
      _nextAttackAt =
          _actionClock +
          switch (archetype) {
            PlatformerEnemyArchetype.patchMite => 1.0,
            PlatformerEnemyArchetype.checksumHopper => 1.25,
            PlatformerEnemyArchetype.pulseTurret => 1.3,
            PlatformerEnemyArchetype.repairLeech => 1.1,
            PlatformerEnemyArchetype.overflowWarden => 0.85,
            _ => 1.5,
          };
    }
  }

  void _executeAction(String id) {
    switch (id) {
      case 'patchMite.bite':
        unawaited(
          _addComponent(
            this,
            EnemyDamageVolumeComponent(
              position: Vector2(size.x / 2 + _facing * 22, size.y / 2),
              size: Vector2(24, 22),
              sourceId: 'enemy.patchMite.bite',
              activeSeconds: 0.18,
            ),
          ),
        );
      case 'checksumHopper.leap':
        _velocity.x = _facing * 92;
        _velocity.y = -405;
        _grounded = false;
        _hopperLandingPending = true;
      case 'pulseTurret.lockedShot':
        unawaited(
          _fireAtPlayer(
            sourceId: 'enemy.pulseTurret.pulseBolt',
            speed: 92,
            color: const Color(0xFFFF4FD8),
          ),
        );
      case 'repairLeech.channel':
        _repairNearestAlly();
      case 'warden.slam':
        final owner = parent;
        if (owner != null) {
          unawaited(
            _addComponent(
              owner,
              EnemyDamageVolumeComponent(
                position: Vector2(position.x, position.y + size.y / 2),
                size: Vector2(190, 22),
                sourceId: 'enemy.overflowWarden.conduitSlam',
                activeSeconds: 0.16,
                volumeColor: const Color(0x77FFB34D),
              ),
            ),
          );
        }
      case 'warden.summonLeech':
        unawaited(_summonWardenLeech());
      case 'warden.guard':
        break;
      case 'tickRunner.threeStepLunge':
        _spawnAttachedStrike('enemy.tickRunner.threeStepLunge', 52, 26, 0.28);
      case 'echoBat.arcReplay':
        if (_motionHistory.isEmpty) {
          _spawnAttachedStrike('enemy.echoBat.arcReplay', 66, 44, 0.34);
        } else {
          for (final index in <int>[
            0,
            _motionHistory.length ~/ 2,
            _motionHistory.length - 1,
          ]) {
            _spawnStrikeAt(
              'enemy.echoBat.arcReplay',
              _motionHistory[index],
              Vector2(42, 42),
              0.34,
            );
          }
        }
      case 'delaySniper.lockedShot':
        unawaited(
          _fireAtPlayer(
            sourceId: 'enemy.delaySniper.delayedShot',
            speed: 168,
            color: const Color(0xFF9D8CFF),
          ),
        );
      case 'rewindSkater.dash':
        _rewindReturning = true;
        _spawnAttachedStrike('enemy.rewindSkater.dashTrail', 62, 22, 0.42);
      case 'rewindSkater.rewind':
        _rewindReturning = false;
        _facing *= -1;
        _spawnAttachedStrike('enemy.rewindSkater.rewindTrail', 76, 24, 0.42);
      case 'chronoJailer.clockSweep':
        _spawnWorldStrike(
          'enemy.chronoJailer.clockHandSweep',
          Vector2(176, 18),
          0.20,
        );
        _spawnWorldStrike(
          'enemy.chronoJailer.clockHandSweep',
          Vector2(18, 150),
          0.20,
        );
      case 'vectorRam.impactCharge':
        _spawnAttachedStrike('enemy.vectorRam.impactCharge', 70, 30, 0.36);
      case 'polarityDrone.pullField':
        _polarityPushes = true;
        final delta = position - game.world.player.position;
        if (delta.length2 > 0) {
          game.world.player.applyExternalImpulse(delta.normalized() * 155);
        }
      case 'polarityDrone.pushField':
        _polarityPushes = false;
        final delta = game.world.player.position - position;
        if (delta.length2 > 0) {
          game.world.player.applyExternalImpulse(delta.normalized() * 190);
        }
      case 'phaseMimic.belowSnap':
        _spawnWorldStrike(
          'enemy.phaseMimic.belowSnap',
          Vector2(58, 70),
          0.16,
          offset: Vector2(0, -34),
        );
      case 'shardLobber.ricochet':
        unawaited(
          _fireAtPlayer(
            sourceId: 'enemy.shardLobber.ricochetShard',
            speed: 138,
            color: const Color(0xFF36E1FF),
            gravity: 260,
            bounces: 2,
          ),
        );
      case 'kernelChimera.polarityCollision':
        _spawnWorldStrike(
          'enemy.kernelChimera.recombineShockwave',
          Vector2(230, 30),
          0.24,
        );
        _spawnStrikeAt(
          'enemy.kernelChimera.cyanHalf',
          position + Vector2(-66, 0),
          Vector2(48, 74),
          0.24,
        );
        _spawnStrikeAt(
          'enemy.kernelChimera.magentaHalf',
          position + Vector2(66, 0),
          Vector2(48, 74),
          0.24,
        );
    }
  }

  void _spawnAttachedStrike(
    String sourceId,
    double width,
    double height,
    double seconds,
  ) {
    unawaited(
      _addComponent(
        this,
        EnemyDamageVolumeComponent(
          position: Vector2(size.x / 2 + _facing * width * 0.35, size.y / 2),
          size: Vector2(width, height),
          sourceId: sourceId,
          activeSeconds: seconds,
          volumeColor: archetype.accentColor.withAlpha(105),
        ),
      ),
    );
  }

  void _spawnWorldStrike(
    String sourceId,
    Vector2 strikeSize,
    double seconds, {
    Vector2? offset,
  }) {
    final owner = parent;
    if (owner == null) return;
    unawaited(
      _addComponent(
        owner,
        EnemyDamageVolumeComponent(
          position: position + (offset ?? Vector2.zero()),
          size: strikeSize,
          sourceId: sourceId,
          activeSeconds: seconds,
          volumeColor: archetype.accentColor.withAlpha(105),
        ),
      ),
    );
  }

  void _spawnStrikeAt(
    String sourceId,
    Vector2 strikePosition,
    Vector2 strikeSize,
    double seconds,
  ) {
    final owner = parent;
    if (owner == null) return;
    unawaited(
      _addComponent(
        owner,
        EnemyDamageVolumeComponent(
          position: strikePosition,
          size: strikeSize,
          sourceId: sourceId,
          activeSeconds: seconds,
          volumeColor: archetype.accentColor.withAlpha(105),
        ),
      ),
    );
  }

  Future<void> _summonWardenLeech() async {
    final owner = parent;
    if (owner == null || isRemoving) return;
    await owner.add(
      PlatformerEnemyComponent(
        archetype: PlatformerEnemyArchetype.repairLeech,
        position: Vector2(
          (position.x - _facing * 76).clamp(
            48,
            PatchWorldGame.logicalWidth - 48,
          ),
          position.y - 12,
        ),
        // Summons are support hazards, not one of the room's five primary kills.
        onDefeated: (_) {},
      ),
    );
  }

  Future<void> _addComponent(Component owner, Component child) async {
    await owner.add(child);
  }

  Future<void> _fireAtPlayer({
    String? sourceId,
    double? speed,
    Color color = const Color(0xFFFF4FD8),
    double gravity = 0,
    int bounces = 0,
  }) async {
    if (!game.world.canSpawnProjectile || isRemoving) return;
    final direction = game.world.player.position - position;
    if (direction.length2 == 0) direction.x = 1;
    direction.normalize();
    await parent?.add(
      EnemyProjectileComponent(
        position: position.clone(),
        velocity: direction * (speed ?? (archetype.isMidBoss ? 145 : 120)),
        sourceId: sourceId ?? 'enemy.${archetype.name}.projectile',
        projectileColor: color,
        gravity: gravity,
        remainingBounces: bounces,
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
    if (nearestDistance <= 230 * 230) nearest?._receiveSupportHealing(1);
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
    if (archetype == PlatformerEnemyArchetype.patchMite &&
        _action?.id == 'patchMite.bite' &&
        _action?.phase == EnemyActionPhase.active) {
      speed = 215;
    }
    if (archetype == PlatformerEnemyArchetype.overflowWarden &&
        _action?.id == 'warden.guard') {
      speed = 0;
    }
    if (archetype == PlatformerEnemyArchetype.tickRunner) speed = 88;
    if (archetype == PlatformerEnemyArchetype.rewindSkater ||
        archetype == PlatformerEnemyArchetype.vectorRam) {
      speed *= 1 + (math.sin(_actionClock * 2.2) > 0.55 ? 1.5 : 0);
    }
    if (_action?.phase == EnemyActionPhase.active) {
      speed = switch (_action?.id) {
        'tickRunner.threeStepLunge' => 230,
        'rewindSkater.dash' => 245,
        'rewindSkater.rewind' => 265,
        'vectorRam.impactCharge' => 280,
        'kernelChimera.polarityCollision' => 185,
        _ => speed,
      };
    }
    _velocity.x = direction * speed;
    final shouldJump =
        (archetype.mobility == PlatformerEnemyMobility.hopper &&
            archetype != PlatformerEnemyArchetype.checksumHopper) ||
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
    if (_grounded && _hopperLandingPending) {
      _hopperLandingPending = false;
      final owner = parent;
      if (owner != null) {
        unawaited(
          _addComponent(
            owner,
            EnemyDamageVolumeComponent(
              position: Vector2(position.x, position.y + size.y / 2),
              size: Vector2(104, 18),
              sourceId: 'enemy.checksumHopper.landingShockwave',
              activeSeconds: 0.14,
              volumeColor: const Color(0x77FFB34D),
            ),
          ),
        );
      }
    }
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
    _combatState = EnemyCombatState.defeated;
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
    if (_spriteVisual != null) {
      _renderSpriteOverlay(canvas);
      return;
    }
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
    if (_combatState == EnemyCombatState.telegraph) {
      canvas.drawRect(
        Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
        Paint()
          ..color = const Color(0xFFFFB34D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = archetype.isMidBoss ? 4 : 3,
      );
      _renderActionTelegraph(canvas, center);
    } else if (_combatState == EnemyCombatState.attacking) {
      canvas.drawCircle(
        center,
        math.min(size.x, size.y) * 0.46,
        Paint()
          ..color = const Color(0xAAFF4FD8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
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

  void _renderSpriteOverlay(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    if (_combatState == EnemyCombatState.telegraph) {
      canvas.drawRect(
        Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
        Paint()
          ..color = const Color(0xFFFFB34D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _renderActionTelegraph(canvas, center);
    }
    final maxRatio = healthState.max / healthState.overflowThreshold;
    final currentRatio = healthState.normalizedForOverflowBar;
    canvas.drawRect(
      Rect.fromLTWH(0, -5, size.x, 3),
      Paint()..color = const Color(0xFF101827),
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

  void _renderActionTelegraph(Canvas canvas, Offset center) {
    final actionId = _action?.id ?? '';
    final tell = Paint()
      ..color = const Color(0xCCFFB34D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (actionId.contains('lockedShot')) {
      canvas.drawLine(center, center + Offset(_facing * 230, 0), tell);
    } else if (actionId == 'checksumHopper.leap') {
      final arc = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          center.dx + _facing * 50,
          center.dy - 78,
          center.dx + _facing * 108,
          center.dy + 12,
        );
      canvas.drawPath(arc, tell);
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(_facing * 108, 16),
          width: 72,
          height: 12,
        ),
        tell,
      );
    } else if (actionId == 'repairLeech.channel') {
      canvas.drawLine(
        center,
        center + Offset(_facing * 94, -20),
        tell..strokeWidth = 4,
      );
    } else if (actionId.contains('polarityDrone')) {
      canvas.drawCircle(center, 62, tell..strokeWidth = 3);
      canvas.drawCircle(center, 44, tell);
    } else if (actionId.contains('ricochet')) {
      for (var index = 1; index <= 5; index += 1) {
        canvas.drawCircle(
          center + Offset(_facing * index * 24, -index * 8 + index * index * 2),
          3,
          tell..style = PaintingStyle.fill,
        );
      }
    } else if (actionId.contains('belowSnap')) {
      canvas.drawLine(
        Offset(4, size.y - 3),
        Offset(size.x - 4, size.y - 3),
        tell..strokeWidth = 4,
      );
    } else if (actionId.contains('clockSweep') ||
        actionId.contains('polarityCollision')) {
      canvas.drawCircle(center, archetype.isMidBoss ? 72 : 52, tell);
      canvas.drawLine(
        center + const Offset(-70, 0),
        center + const Offset(70, 0),
        tell,
      );
      canvas.drawLine(
        center + const Offset(0, -60),
        center + const Offset(0, 60),
        tell,
      );
    } else {
      canvas.drawLine(center, center + Offset(_facing * 70, 0), tell);
    }
  }
}
