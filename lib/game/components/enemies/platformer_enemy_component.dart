import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/effects/enemy_damage_volume_component.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_action_timeline.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_art_v3_frame_resolver.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_attack_pattern.dart';
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

  String get artV3AssetPath => 'sprites/art_v3/enemies/$assetSlug.png';

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
    this.startsDormant = false,
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
  final bool startsDormant;
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
  late bool _dormant = startsDormant;
  double _facing = 1;
  EnemyActionTimeline? _action;
  EnemyCombatState _combatState = EnemyCombatState.idle;
  bool _hopperLandingPending = false;
  bool _wardenSummonedAtHighThreshold = false;
  bool _wardenSummonedAtLowThreshold = false;
  int _wardenPatternIndex = 0;
  bool _rewindReturning = false;
  bool _polarityPushes = false;
  int _projectilePatternIndex = 0;
  int _combatPatternIndex = 0;
  final List<String> _recentActionIds = <String>[];
  int _activeMotionFrame = 3;
  double _visualClock = 0;
  double _hurtTimer = 0;
  double _defeatTimer = 0;
  SpriteComponent? _spriteVisual;
  TextComponent? _nameLabel;
  List<Sprite>? _spriteFrames;
  List<Sprite>? _artV3Frames;
  final List<Vector2> _motionHistory = <Vector2>[];
  final Vector2 _lockedTargetPosition = Vector2.zero();
  double? _patternHorizontalVelocity;
  EnemyDamageEffectSpec? _pendingLandingEffect;
  String? _pendingLandingSourceId;

  @override
  String get entityId => 'platformer.${archetype.name}';

  int get health => healthState.current;
  bool get isOverflowing => _overflowTimer > 0;
  bool get hasArtV3Visual => _artV3Frames?.length == 8;
  EnemyCombatState get combatState => _combatState;
  String? get activeActionId => _action?.id;
  bool get dealsContactDamage => false;
  bool get isDormant => _dormant;
  bool get isActiveThreat => !_dormant && !_resolved && !isRemoving;

  @visibleForTesting
  void debugExecutePatternSlot(EnemyActionSlot slot) {
    _lockedTargetPosition.setFrom(game.world.player.position);
    final direction = _lockedTargetPosition.x - position.x;
    if (direction.abs() > .01) _facing = direction.sign.toDouble();
    _executePatternAction(
      EnemyAttackPatternCatalog.forArchetype(
        archetype.name,
      ).actionForSlot(slot),
    );
  }

  @visibleForTesting
  double? get debugPatternHorizontalVelocity => _patternHorizontalVelocity;

  double get _activeWorldWidth {
    final room = game.world.activeRoom;
    return room is PlatformerRoomGeometry
        ? (room as PlatformerRoomGeometry).worldSize.x
        : PatchWorldGame.logicalWidth;
  }

  double get _activeWorldHeight {
    final room = game.world.activeRoom;
    return room is PlatformerRoomGeometry
        ? (room as PlatformerRoomGeometry).worldSize.y
        : PatchWorldGame.logicalHeight;
  }

  void activateEncounter() {
    if (!_dormant || _resolved) return;
    _dormant = false;
    _nextAttackAt = _actionClock + .8;
    scale.setAll(1);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (_dormant) scale.setAll(0);
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
    _nameLabel = TextComponent(
      text: game.localization.text('enemy.${archetype.name}.name'),
      position: Vector2(size.x / 2, -10),
      anchor: Anchor.bottomCenter,
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'PatchWorldCJK',
          color: archetype.accentColor,
          fontSize: archetype.isMidBoss ? 9 : 7,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
    await add(_nameLabel!);
  }

  void refreshLocalizedText() {
    _nameLabel?.text = game.localization.text('enemy.${archetype.name}.name');
  }

  Future<void> _loadSpriteVisual() async {
    try {
      final image = await game.images.load(
        'sprites/combat_v2/enemies/${archetype.assetSlug}.png',
      );
      if (isRemoving) return;
      final frames = List<Sprite>.generate(
        10,
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
      try {
        final artV3Image = await game.images.load(archetype.artV3AssetPath);
        _artV3Frames = List<Sprite>.generate(
          8,
          (index) => Sprite(
            artV3Image,
            srcPosition: Vector2(index * 256.0, 0),
            srcSize: Vector2.all(256),
          ),
        );
      } catch (_) {
        // Art v3 is presentation-only. Combat Motion v2 remains the fallback.
      }
      _spriteVisual = visual;
      await add(visual);
    } catch (_) {
      // Procedural proxy remains available during development.
    }
  }

  @override
  void receiveDamage(int amount) {
    if (_resolved || _dormant || amount <= 0) return;
    final mutation = healthState.applyDamage(amount);
    if (mutation == HealthMutation.defeated) {
      _resolveDefeat();
    } else {
      _hurtTimer = .20;
      _combatState = EnemyCombatState.hurt;
    }
  }

  @override
  void receiveHealing(int amount) {
    if (_resolved || _dormant || amount <= 0) return;
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
    _visualClock += simulationDt;
    if (_overflowTimer > 0) {
      _combatState = EnemyCombatState.overflowing;
      _overflowTimer -= simulationDt;
      scale.setAll(1 + (0.36 - _overflowTimer) * 0.7);
      if (_overflowTimer <= 0) _resolveDefeat(corrupted: true);
      super.update(dt);
      return;
    }
    if (!game.world.isReady) {
      super.update(dt);
      return;
    }
    if (_resolved) {
      _defeatTimer = math.max(0, _defeatTimer - simulationDt);
      _combatState = EnemyCombatState.defeated;
      _syncSpriteVisual();
      if (_defeatTimer <= 0) removeFromParent();
      super.update(dt);
      return;
    }
    if (_dormant) {
      _combatState = EnemyCombatState.idle;
      _syncSpriteVisual();
      scale.setAll(0);
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
    _hurtTimer = math.max(0, _hurtTimer - enemyDt);
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
    if (_hurtTimer > 0) {
      _combatState = EnemyCombatState.hurt;
    } else if (_action == null) {
      _combatState = _velocity.length2 > 1
          ? EnemyCombatState.moving
          : EnemyCombatState.idle;
    }
    _syncSpriteVisual();
    super.update(dt);
  }

  void _updateMotionHistory() {
    if (archetype == PlatformerEnemyArchetype.echoBat ||
        archetype == PlatformerEnemyArchetype.chronoJailer) {
      _motionHistory.add(game.world.player.position.clone());
    } else if (archetype == PlatformerEnemyArchetype.rewindSkater ||
        archetype == PlatformerEnemyArchetype.tickRunner) {
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
      EnemyCombatState.telegraph => 2,
      EnemyCombatState.attacking ||
      EnemyCombatState.recovering => _activeMotionFrame,
      EnemyCombatState.hurt ||
      EnemyCombatState.staggered ||
      EnemyCombatState.overflowing => 8,
      EnemyCombatState.defeated => 9,
    };
    final artV3Frames = _artV3Frames;
    final usesActionSpecificAttackFrame = usesCombatMotionAttackFrame(
      state: _combatState,
      motionFrame: _activeMotionFrame,
    );
    if (artV3Frames == null ||
        usesActionSpecificAttackFrame ||
        _combatState == EnemyCombatState.hurt ||
        _combatState == EnemyCombatState.staggered ||
        _combatState == EnemyCombatState.overflowing ||
        _combatState == EnemyCombatState.defeated) {
      visual.sprite = frames[frameIndex];
    } else {
      final artV3FrameIndex = resolveArtV3EnemyFrame(
        state: _combatState,
        visualClock: _visualClock,
        archetypeIndex: archetype.index,
      );
      visual.sprite = artV3Frames[artV3FrameIndex];
    }
    final bob =
        math.sin(_visualClock * 5 + archetype.index) *
        (_combatState == EnemyCombatState.moving ? 2.2 : 1.0);
    var offsetX = 0.0;
    var scaleX = 1.0;
    var scaleY = 1.0;
    var angle = math.sin(_visualClock * 2.2 + archetype.index) * .012;
    switch (_combatState) {
      case EnemyCombatState.telegraph:
        break;
      case EnemyCombatState.attacking:
        offsetX = _facing * 7;
        angle = _facing * -.045;
      case EnemyCombatState.recovering:
        offsetX = _facing * 2;
      case EnemyCombatState.hurt || EnemyCombatState.staggered:
        offsetX = -_facing * 5;
        angle = -_facing * .08;
      case EnemyCombatState.overflowing:
        scaleX = 1.13;
        scaleY = 1.13;
      case EnemyCombatState.defeated:
        scaleX = 1 - (1 - (_defeatTimer / .28).clamp(0, 1)) * .25;
        scaleY = scaleX;
        angle = _facing * (1 - (_defeatTimer / .28).clamp(0, 1)) * .18;
      case EnemyCombatState.idle || EnemyCombatState.moving:
        break;
    }
    visual.position.setValues(size.x / 2 + offsetX, size.y / 2 + bob);
    visual.scale.setValues(_facing * scaleX, scaleY);
    visual.angle = angle;
  }

  void _scheduleDamageLabAction() {
    if (_action != null || _actionClock < _nextAttackAt) return;
    final playerDistance = game.world.player.position.distanceTo(position);
    switch (archetype) {
      case PlatformerEnemyArchetype.patchMite:
        if (playerDistance <= 145) {
          _beginPatternAction();
        }
      case PlatformerEnemyArchetype.checksumHopper:
        if (_grounded && playerDistance <= 310) {
          _beginPatternAction();
        }
      case PlatformerEnemyArchetype.pulseTurret:
        if (playerDistance <= 520) {
          _beginPatternAction();
        }
      case PlatformerEnemyArchetype.repairLeech:
        if (playerDistance <= 520) {
          _beginPatternAction();
        }
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
          _beginPatternAction();
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
    if (game.world.player.position.distanceTo(position) > 650) return;
    final variant = switch (archetype) {
      PlatformerEnemyArchetype.rewindSkater =>
        _rewindReturning ? 'rewind' : null,
      PlatformerEnemyArchetype.polarityDrone => _polarityPushes ? 'push' : null,
      _ => null,
    };
    if (variant == null) {
      _beginPatternAction();
    } else {
      _beginBrainAction(variant: variant);
    }
  }

  void _beginAction({
    required String id,
    required double telegraph,
    required double active,
    required double recovery,
    int motionFrame = 3,
  }) {
    _action = EnemyActionTimeline(
      id: id,
      telegraphSeconds: telegraph,
      activeSeconds: active,
      recoverySeconds: recovery,
    );
    _combatState = EnemyCombatState.telegraph;
    _activeMotionFrame = motionFrame.clamp(3, 7);
    _patternHorizontalVelocity = null;
    _lockedTargetPosition.setFrom(game.world.player.position);
    final direction = _lockedTargetPosition.x - position.x;
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
      motionFrame: variant == null ? 3 : 7,
    );
  }

  void _beginPatternAction() {
    final player = game.world.player;
    final allies = parent?.children
        .whereType<PlatformerEnemyComponent>()
        .where(
          (enemy) =>
              enemy != this &&
              !enemy._resolved &&
              !enemy._dormant &&
              enemy.position.distanceTo(position) <= 260,
        )
        .toList(growable: false);
    final nearbyAllies = allies?.length ?? 0;
    final activeAllyAttackers =
        allies
            ?.where(
              (enemy) =>
                  enemy._combatState == EnemyCombatState.telegraph ||
                  enemy._combatState == EnemyCombatState.attacking,
            )
            .length ??
        0;
    final formationSlot = ((_homePosition.x ~/ 96) + archetype.index).abs() % 3;
    final selection = PlatformerEnemyBrain.chooseAction(
      archetype.name,
      EnemyCombatContext(
        distance: player.position.distanceTo(position),
        verticalDelta: (player.position.y - position.y).abs(),
        healthRatio: healthState.current / healthState.overflowThreshold,
        playerGrounded: player.isGrounded,
        playerWeapon: player.selectedWeapon,
        nearbyAllies: nearbyAllies,
        activeAllyAttackers: activeAllyAttackers,
        formationSlot: formationSlot,
        recentActionIds: List<String>.unmodifiable(_recentActionIds),
        decisionSeed: _combatPatternIndex,
      ),
    );
    _combatPatternIndex += 1;
    final decision = selection.decision;
    _recentActionIds.insert(0, decision.actionId);
    if (_recentActionIds.length > 3) _recentActionIds.removeLast();
    _beginAction(
      id: decision.actionId,
      telegraph: decision.telegraph,
      active: decision.active,
      recovery: decision.recovery,
      motionFrame: selection.motionFrame,
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
      _patternHorizontalVelocity = null;
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
    unawaited(game.audio.playEnemyAttack(id));
    final pattern = EnemyAttackPatternCatalog.forArchetype(
      archetype.name,
    ).resolveAction(id);
    if (pattern != null) {
      _executePatternAction(pattern);
      return;
    }
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
          _fireAtPlayer(sourceId: 'enemy.pulseTurret.pulseBolt', speed: 92),
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
          _fireAtPlayer(sourceId: 'enemy.delaySniper.delayedShot', speed: 168),
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
          (position.x - _facing * 76).clamp(48, _activeWorldWidth - 48),
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
    AttackTier? tier,
    Vector2? targetPosition,
    double gravity = 0,
    int bounces = 0,
    double angleOffset = 0,
    double impactImpulse = 0,
  }) async {
    if (!game.world.canSpawnProjectile || isRemoving) return;
    final resolvedTier = tier ?? _nextProjectileTier();
    final direction = (targetPosition ?? _lockedTargetPosition) - position;
    if (direction.length2 == 0) direction.x = 1;
    direction.normalize();
    if (angleOffset != 0) direction.rotate(angleOffset);
    final speedMultiplier = switch (resolvedTier) {
      AttackTier.normal => 1.0,
      AttackTier.enhanced => 1.12,
      AttackTier.parryable => 0.72,
    };
    await parent?.add(
      EnemyProjectileComponent(
        position: position.clone(),
        velocity:
            direction *
            (speed ?? (archetype.isMidBoss ? 145 : 120)) *
            speedMultiplier,
        sourceId:
            '${sourceId ?? 'enemy.${archetype.name}.projectile'}.${resolvedTier.name}',
        attackTier: resolvedTier,
        assetSlug: archetype.assetSlug,
        damage: resolvedTier == AttackTier.enhanced ? 2 : 1,
        projectileRadius: resolvedTier == AttackTier.enhanced ? 10 : 7,
        gravity: gravity,
        remainingBounces: bounces,
        impactImpulse: impactImpulse,
      ),
    );
  }

  AttackTier _nextProjectileTier() {
    final tier = AttackTier.values[_projectilePatternIndex % 3];
    _projectilePatternIndex += 1;
    return tier;
  }

  void _executePatternAction(EnemyAttackSpec action) {
    for (var index = 0; index < action.effects.length; index += 1) {
      final effect = action.effects[index];
      final sourceId =
          'enemy.${archetype.name}.${action.slot.name}.${action.motionId}.$index';
      switch (effect) {
        case EnemyProjectileEffectSpec():
          unawaited(_spawnPatternProjectiles(effect, sourceId));
        case EnemyDamageEffectSpec():
          _executeDamageEffect(effect, sourceId);
        case EnemyMovementEffectSpec():
          _executeMovementEffect(effect, sourceId);
        case EnemyImpulseEffectSpec():
          _executeImpulseEffect(effect);
        case EnemySupportEffectSpec():
          _executeSupportEffect(effect);
      }
    }
  }

  Future<void> _spawnPatternProjectiles(
    EnemyProjectileEffectSpec effect,
    String sourceId,
  ) async {
    final owner = parent;
    if (owner == null || isRemoving) return;
    final towardTarget = _lockedTargetPosition - position;
    if (towardTarget.length2 == 0) towardTarget.x = _facing;
    towardTarget.normalize();
    final velocities = <Vector2>[];
    switch (effect.pattern) {
      case EnemyProjectilePattern.aimed || EnemyProjectilePattern.fan:
        final center = (effect.count - 1) / 2;
        for (var index = 0; index < effect.count; index += 1) {
          final direction = towardTarget.clone()
            ..rotate((index - center) * effect.spreadRadians);
          velocities.add(direction * effect.speed);
        }
      case EnemyProjectilePattern.facing:
        final center = (effect.count - 1) / 2;
        for (var index = 0; index < effect.count; index += 1) {
          final direction = Vector2(_facing, 0)
            ..rotate((index - center) * effect.spreadRadians);
          velocities.add(direction * effect.speed);
        }
      case EnemyProjectilePattern.radial:
        for (var index = 0; index < effect.count; index += 1) {
          final angle = math.pi * 2 * index / effect.count;
          velocities.add(
            Vector2(math.cos(angle), math.sin(angle)) * effect.speed,
          );
        }
      case EnemyProjectilePattern.ballistic:
        final center = (effect.count - 1) / 2;
        final horizontalDirection = towardTarget.x.sign == 0
            ? _facing
            : towardTarget.x.sign.toDouble();
        for (var index = 0; index < effect.count; index += 1) {
          final offset = index - center;
          velocities.add(
            Vector2(
              horizontalDirection * effect.speed * (1 + offset.abs() * .07),
              -effect.verticalSpeed +
                  offset * effect.spreadRadians * effect.speed,
            ),
          );
        }
    }

    for (var index = 0; index < velocities.length; index += 1) {
      if (isRemoving || parent != owner || !game.world.canSpawnProjectile) {
        break;
      }
      await owner.add(
        EnemyProjectileComponent(
          position: position.clone(),
          velocity: velocities[index],
          sourceId: '$sourceId.$index',
          attackTier: effect.tier,
          assetSlug: archetype.assetSlug,
          damage: effect.damage,
          projectileRadius: effect.radius,
          gravity: effect.gravity,
          remainingBounces: effect.bounces,
          impactImpulse: effect.impactImpulse,
        ),
      );
    }
  }

  void _executeDamageEffect(EnemyDamageEffectSpec effect, String sourceId) {
    final owner = parent;
    if (owner == null) return;
    switch (effect.placement) {
      case EnemyDamagePlacement.attachedFront:
        final center = (effect.count - 1) / 2;
        for (var index = 0; index < effect.count; index += 1) {
          _spawnDamageVolume(
            this,
            Vector2(
              size.x / 2 + _facing * effect.width * .34,
              size.y / 2 + (index - center) * effect.spacing,
            ),
            effect,
            '$sourceId.$index',
          );
        }
      case EnemyDamagePlacement.selfCentered:
        _spawnDamageSeries(owner, position.clone(), effect, sourceId);
      case EnemyDamagePlacement.groundAtSelf:
        _spawnDamageSeries(
          owner,
          Vector2(position.x, position.y + size.y / 2),
          effect,
          sourceId,
        );
      case EnemyDamagePlacement.targetCentered:
        _spawnDamageSeries(
          owner,
          _lockedTargetPosition.clone(),
          effect,
          sourceId,
        );
      case EnemyDamagePlacement.targetBelow:
        _spawnDamageSeries(
          owner,
          _lockedTargetPosition + Vector2(0, effect.height * .38),
          effect,
          sourceId,
        );
      case EnemyDamagePlacement.historyTrail:
        final points = _sampleMotionHistory(effect.count);
        for (var index = 0; index < points.length; index += 1) {
          _spawnDamageVolume(owner, points[index], effect, '$sourceId.$index');
        }
      case EnemyDamagePlacement.crossAtSelf:
        _spawnDamageCross(owner, position.clone(), effect, sourceId);
      case EnemyDamagePlacement.crossAtTarget:
        _spawnDamageCross(
          owner,
          _lockedTargetPosition.clone(),
          effect,
          sourceId,
        );
    }
  }

  void _spawnDamageSeries(
    Component owner,
    Vector2 base,
    EnemyDamageEffectSpec effect,
    String sourceId,
  ) {
    final center = (effect.count - 1) / 2;
    for (var index = 0; index < effect.count; index += 1) {
      _spawnDamageVolume(
        owner,
        base + Vector2((index - center) * effect.spacing, 0),
        effect,
        '$sourceId.$index',
      );
    }
  }

  void _spawnDamageCross(
    Component owner,
    Vector2 center,
    EnemyDamageEffectSpec effect,
    String sourceId,
  ) {
    _spawnDamageVolume(owner, center, effect, '$sourceId.horizontal');
    _spawnDamageVolume(
      owner,
      center,
      EnemyDamageEffectSpec(
        placement: effect.placement,
        width: effect.height,
        height: effect.width,
        activeSeconds: effect.activeSeconds,
        damage: effect.damage,
      ),
      '$sourceId.vertical',
    );
  }

  void _spawnDamageVolume(
    Component owner,
    Vector2 strikePosition,
    EnemyDamageEffectSpec effect,
    String sourceId,
  ) {
    unawaited(
      _addComponent(
        owner,
        EnemyDamageVolumeComponent(
          position: strikePosition,
          size: Vector2(effect.width, effect.height),
          sourceId: sourceId,
          damage: effect.damage,
          activeSeconds: effect.activeSeconds,
          volumeColor: archetype.accentColor.withAlpha(105),
        ),
      ),
    );
  }

  List<Vector2> _sampleMotionHistory(int count) {
    if (_motionHistory.isEmpty) {
      return <Vector2>[_lockedTargetPosition.clone()];
    }
    if (count == 1) return <Vector2>[_motionHistory.last.clone()];
    return <Vector2>[
      for (var index = 0; index < count; index += 1)
        _motionHistory[(index * (_motionHistory.length - 1) / (count - 1))
                .round()]
            .clone(),
    ];
  }

  void _executeMovementEffect(EnemyMovementEffectSpec effect, String sourceId) {
    final targetDirection = (_lockedTargetPosition.x - position.x).sign;
    final toward = targetDirection == 0 ? _facing : targetDirection.toDouble();
    switch (effect.mode) {
      case EnemyMovementMode.dashTowardTarget:
        _facing = toward;
        _patternHorizontalVelocity = toward * effect.speed;
      case EnemyMovementMode.dashAwayFromTarget:
        _facing = -toward;
        _patternHorizontalVelocity = -toward * effect.speed;
      case EnemyMovementMode.leapTowardTarget:
        _facing = toward;
        _patternHorizontalVelocity = toward * effect.speed;
        _velocity
          ..x = _patternHorizontalVelocity!
          ..y = -effect.verticalSpeed;
        _grounded = false;
        _pendingLandingEffect = effect.landingEffect;
        _pendingLandingSourceId = '$sourceId.landing';
      case EnemyMovementMode.teleportOppositeSide:
        position.x = (_activeWorldWidth - position.x).clamp(
          72,
          _activeWorldWidth - 72,
        );
      case EnemyMovementMode.teleportAboveTarget:
        position.setValues(
          _lockedTargetPosition.x.clamp(70, _activeWorldWidth - 70),
          (_lockedTargetPosition.y -
                  (effect.distance == 0 ? 130 : effect.distance))
              .clamp(70, _activeWorldHeight - 70),
        );
      case EnemyMovementMode.rewindOldestPosition:
        if (_motionHistory.isNotEmpty) {
          position.setFrom(_motionHistory.first);
        }
    }
  }

  void _executeImpulseEffect(EnemyImpulseEffectSpec effect) {
    final player = game.world.player;
    final direction = switch (effect.mode) {
      EnemyImpulseMode.pull => position - player.position,
      EnemyImpulseMode.push => player.position - position,
    };
    if (direction.length2 == 0) direction.x = _facing;
    player.applyExternalImpulse(direction.normalized() * effect.strength);
  }

  void _executeSupportEffect(EnemySupportEffectSpec effect) {
    switch (effect.mode) {
      case EnemySupportMode.healSelf:
        _receiveSupportHealing(effect.amount);
      case EnemySupportMode.healNearestAlly:
        _repairNearestAlly(effect.amount);
      case EnemySupportMode.summonLeech:
        unawaited(_summonWardenLeech());
    }
  }

  void _repairNearestAlly([int amount = 1]) {
    PlatformerEnemyComponent? nearest;
    var nearestDistance = double.infinity;
    for (final target in game.world.activeCombatTargets) {
      if (target is! PlatformerEnemyComponent ||
          identical(target, this) ||
          !target.isActiveThreat) {
        continue;
      }
      final distance = position.distanceToSquared(target.position);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = target;
      }
    }
    if (nearestDistance <= 230 * 230) nearest?._receiveSupportHealing(amount);
  }

  void _updateFlying(double dt) {
    final forcedVelocity = _action?.phase == EnemyActionPhase.active
        ? _patternHorizontalVelocity
        : null;
    if (forcedVelocity != null) {
      position.x += forcedVelocity * dt;
      position.x = position.x.clamp(36, _activeWorldWidth - 36);
      return;
    }
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
    position.x = position.x.clamp(36, _activeWorldWidth - 36);
    position.y = position.y.clamp(70, _activeWorldHeight - 70);
  }

  void _updateTurret(double dt, Iterable<Rect> solids) {
    scale.setAll(1);
    _velocity.y = math.min(620, _velocity.y + 1100 * dt);
    _moveVertical(dt, solids);
  }

  void _updateGrounded(double dt, Iterable<Rect> solids) {
    final player = game.world.player.position;
    final playerDistanceX = (player.x - position.x).abs();
    final aggroRange = switch (archetype) {
      PlatformerEnemyArchetype.repairLeech => 300.0,
      _ when archetype.isMidBoss => 300.0,
      _ => 220.0,
    };
    final patrolTarget = _homePosition.x + math.sin(_actionClock * 0.8) * 46;
    var targetX = patrolTarget;
    if (playerDistanceX <= aggroRange) {
      final towardPlayer = player.x - position.x;
      final formationSlot =
          ((_homePosition.x ~/ 96) + archetype.index).abs() % 3;
      final idealRange = switch (archetype) {
        PlatformerEnemyArchetype.repairLeech => 164.0 + formationSlot * 18,
        PlatformerEnemyArchetype.checksumHopper => 76.0 + formationSlot * 12,
        _ when archetype.isMidBoss => 92.0 + formationSlot * 14,
        _ => 48.0 + formationSlot * 14,
      };
      if (playerDistanceX > idealRange + 18) {
        targetX = player.x;
      } else if (playerDistanceX < idealRange - 18) {
        final retreatDirection = towardPlayer.sign == 0
            ? _facing
            : towardPlayer.sign.toDouble();
        targetX = position.x - retreatDirection * 80;
      } else {
        targetX = position.x;
      }
    }
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
    if (_action?.phase == EnemyActionPhase.active &&
        _patternHorizontalVelocity != null) {
      _velocity.x = _patternHorizontalVelocity!;
    }
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
    final landingEffect = _pendingLandingEffect;
    if (_grounded && landingEffect != null) {
      _pendingLandingEffect = null;
      final sourceId =
          _pendingLandingSourceId ?? 'enemy.${archetype.name}.landing';
      _pendingLandingSourceId = null;
      _executeDamageEffect(landingEffect, sourceId);
    }
    final activeRoom = game.world.activeRoom;
    final killPlane = activeRoom is PlatformerRoomGeometry
        ? (activeRoom as PlatformerRoomGeometry).killPlaneY
        : PatchWorldGame.logicalHeight + 80;
    if (position.y > killPlane) {
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
    _defeatTimer = .28;
    _combatState = EnemyCombatState.defeated;
    _syncSpriteVisual();
    if (isMounted) {
      game.world.spawnDataShards(
        position,
        count: archetype.isMidBoss ? 5 : 2,
        corrupted: corrupted,
      );
    }
    onDefeated(this);
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
    if (_dormant) {
      canvas.drawCircle(
        center,
        math.max(size.x, size.y) * .58,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x99FFD35A),
      );
      canvas.drawLine(
        center + const Offset(-12, -12),
        center + const Offset(12, 12),
        Paint()
          ..strokeWidth = 3
          ..color = const Color(0x99FFD35A),
      );
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
    final pattern = EnemyAttackPatternCatalog.forArchetype(
      archetype.name,
    ).resolveAction(actionId);
    if (pattern != null) {
      _renderPatternTelegraph(canvas, center, tell, pattern);
      return;
    }
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

  void _renderPatternTelegraph(
    Canvas canvas,
    Offset center,
    Paint tell,
    EnemyAttackSpec action,
  ) {
    for (final effect in action.effects) {
      switch (effect) {
        case EnemyProjectileEffectSpec():
          _renderProjectileTelegraph(canvas, center, tell, effect);
        case EnemyDamageEffectSpec():
          _renderDamageTelegraph(canvas, center, tell, effect);
        case EnemyMovementEffectSpec():
          _renderMovementTelegraph(canvas, center, tell, effect);
          final landing = effect.landingEffect;
          if (landing != null) {
            _renderDamageTelegraph(canvas, center, tell, landing);
          }
        case EnemyImpulseEffectSpec():
          final radius = effect.strength.clamp(80, 270).toDouble() * .28;
          canvas.drawCircle(center, radius, tell..strokeWidth = 3);
          canvas.drawCircle(center, radius * .66, tell..strokeWidth = 2);
        case EnemySupportEffectSpec():
          final supportPaint = Paint()
            ..color = const Color(0xCC65FFB1)
            ..strokeWidth = 3;
          canvas.drawLine(
            center + const Offset(-10, 0),
            center + const Offset(10, 0),
            supportPaint,
          );
          canvas.drawLine(
            center + const Offset(0, -10),
            center + const Offset(0, 10),
            supportPaint,
          );
      }
    }
  }

  void _renderProjectileTelegraph(
    Canvas canvas,
    Offset center,
    Paint tell,
    EnemyProjectileEffectSpec effect,
  ) {
    final tierPaint = Paint()
      ..color = effect.tier == AttackTier.parryable
          ? const Color(0xFFFFD35A)
          : tell.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = effect.tier == AttackTier.enhanced ? 3 : 2;
    final targetDelta = _lockedTargetPosition - position;
    if (targetDelta.length2 == 0) targetDelta.x = _facing;
    targetDelta.normalize();
    switch (effect.pattern) {
      case EnemyProjectilePattern.aimed || EnemyProjectilePattern.fan:
        final midpoint = (effect.count - 1) / 2;
        for (var index = 0; index < effect.count; index += 1) {
          final direction = targetDelta.clone()
            ..rotate((index - midpoint) * effect.spreadRadians);
          canvas.drawLine(
            center,
            center + Offset(direction.x, direction.y) * 170,
            tierPaint,
          );
        }
      case EnemyProjectilePattern.facing:
        final midpoint = (effect.count - 1) / 2;
        for (var index = 0; index < effect.count; index += 1) {
          final direction = Vector2(_facing, 0)
            ..rotate((index - midpoint) * effect.spreadRadians);
          canvas.drawLine(
            center,
            center + Offset(direction.x, direction.y) * 150,
            tierPaint,
          );
        }
      case EnemyProjectilePattern.radial:
        for (var index = 0; index < effect.count; index += 1) {
          final angle = math.pi * 2 * index / effect.count;
          canvas.drawLine(
            center,
            center + Offset(math.cos(angle), math.sin(angle)) * 78,
            tierPaint,
          );
        }
      case EnemyProjectilePattern.ballistic:
        final midpoint = (effect.count - 1) / 2;
        for (var index = 0; index < effect.count; index += 1) {
          final offset = index - midpoint;
          final end = center + Offset(_facing * 148, 34 + offset * 18);
          final path = Path()
            ..moveTo(center.dx, center.dy)
            ..quadraticBezierTo(
              center.dx + _facing * 74,
              center.dy - 92 + offset * 10,
              end.dx,
              end.dy,
            );
          canvas.drawPath(path, tierPaint);
        }
    }
  }

  void _renderDamageTelegraph(
    Canvas canvas,
    Offset center,
    Paint tell,
    EnemyDamageEffectSpec effect,
  ) {
    Offset base;
    switch (effect.placement) {
      case EnemyDamagePlacement.attachedFront:
        base = center + Offset(_facing * effect.width * .34, 0);
      case EnemyDamagePlacement.selfCentered:
        base = center;
      case EnemyDamagePlacement.groundAtSelf:
        base = center + Offset(0, size.y / 2);
      case EnemyDamagePlacement.targetCentered ||
          EnemyDamagePlacement.crossAtTarget:
        base = _worldToLocal(_lockedTargetPosition, center);
      case EnemyDamagePlacement.targetBelow:
        base = _worldToLocal(
          _lockedTargetPosition + Vector2(0, effect.height * .38),
          center,
        );
      case EnemyDamagePlacement.historyTrail:
        for (final point in _sampleMotionHistory(effect.count)) {
          _drawTelegraphRect(
            canvas,
            _worldToLocal(point, center),
            effect.width,
            effect.height,
            tell,
          );
        }
        return;
      case EnemyDamagePlacement.crossAtSelf:
        base = center;
    }
    if (effect.placement == EnemyDamagePlacement.crossAtSelf ||
        effect.placement == EnemyDamagePlacement.crossAtTarget) {
      _drawTelegraphRect(canvas, base, effect.width, effect.height, tell);
      _drawTelegraphRect(canvas, base, effect.height, effect.width, tell);
      return;
    }
    final midpoint = (effect.count - 1) / 2;
    for (var index = 0; index < effect.count; index += 1) {
      _drawTelegraphRect(
        canvas,
        base + Offset((index - midpoint) * effect.spacing, 0),
        effect.width,
        effect.height,
        tell,
      );
    }
  }

  void _renderMovementTelegraph(
    Canvas canvas,
    Offset center,
    Paint tell,
    EnemyMovementEffectSpec effect,
  ) {
    final toward = (_lockedTargetPosition.x - position.x).sign == 0
        ? _facing
        : (_lockedTargetPosition.x - position.x).sign.toDouble();
    final direction = switch (effect.mode) {
      EnemyMovementMode.dashAwayFromTarget => -toward,
      _ => toward,
    };
    switch (effect.mode) {
      case EnemyMovementMode.dashTowardTarget ||
          EnemyMovementMode.dashAwayFromTarget:
        canvas.drawLine(
          center,
          center + Offset(direction * 120, 0),
          tell..strokeWidth = 4,
        );
      case EnemyMovementMode.leapTowardTarget:
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..quadraticBezierTo(
            center.dx + direction * 58,
            center.dy - 90,
            center.dx + direction * 118,
            center.dy + 8,
          );
        canvas.drawPath(path, tell..strokeWidth = 3);
      case EnemyMovementMode.teleportOppositeSide:
        canvas.drawCircle(center, 34, tell);
        canvas.drawCircle(
          _worldToLocal(
            Vector2(_activeWorldWidth - position.x, position.y),
            center,
          ),
          34,
          tell,
        );
      case EnemyMovementMode.teleportAboveTarget:
        final destination =
            _lockedTargetPosition +
            Vector2(0, -(effect.distance == 0 ? 130.0 : effect.distance));
        canvas.drawLine(center, _worldToLocal(destination, center), tell);
      case EnemyMovementMode.rewindOldestPosition:
        if (_motionHistory.isNotEmpty) {
          canvas.drawLine(
            center,
            _worldToLocal(_motionHistory.first, center),
            tell..strokeWidth = 3,
          );
        }
    }
  }

  Offset _worldToLocal(Vector2 worldPoint, Offset center) =>
      center + Offset(worldPoint.x - position.x, worldPoint.y - position.y);

  void _drawTelegraphRect(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    canvas.drawRect(
      Rect.fromCenter(center: center, width: width, height: height),
      paint,
    );
  }
}
