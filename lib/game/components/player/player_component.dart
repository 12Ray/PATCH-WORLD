import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/combat/player_combat_animation.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/effects/player_strike_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/player/player_animation_state_resolver.dart';
import 'package:patch_world/game/components/player/platformer_motion.dart';
import 'package:patch_world/game/components/projectiles/player_projectile_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
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
  static const double parryWindowSeconds = 0.20;
  static const double parryRecoverySeconds = 0.48;
  static const double dashDistance = 92;
  static const double dashDurationSeconds = 0.15;
  static const double dashCooldownSeconds = 5;
  static const double dashContactImmunitySeconds = 0.08;

  final Vector2 spawnPosition;
  final Vector2 _movementInput = Vector2.zero();
  final Vector2 _previousPosition = Vector2.zero();
  final PlatformerMotion _platformerMotion = PlatformerMotion();
  bool _jumpHeld = false;

  int maxIntegrity = 5;
  int integrity = 5;

  double _attackCooldown = 0;
  double _hitInvulnerability = 0;
  int _dataShardCharge = 0;
  EntitySpriteVisual? _visual;
  List<Sprite>? _idleFrames;
  List<Sprite>? _moveFrames;
  List<Sprite>? _pulseFrames;
  List<Sprite>? _hurtFrames;
  final Map<PlayerWeapon, List<Sprite>> _weaponFrames =
      <PlayerWeapon, List<Sprite>>{};
  final Map<PlayerWeapon, Map<PlayerAnimationState, List<Sprite>>>
  _weaponLocomotionFrames =
      <PlayerWeapon, Map<PlayerAnimationState, List<Sprite>>>{};
  final Map<PlayerWeapon, Map<PlayerCombatAnimation, List<Sprite>>>
  _weaponCombatFrames =
      <PlayerWeapon, Map<PlayerCombatAnimation, List<Sprite>>>{};
  List<Sprite>? _gauntletDoubleJumpFrames;
  List<Sprite>? _swordDashFrames;
  List<Sprite>? _gunRailFrames;
  PlayerAnimationState? _activeMovementAnimation;
  PlayerWeapon selectedWeapon = PlayerWeapon.sword;
  int _weaponComboStep = 0;
  double _weaponComboReset = 0;
  double _parryWindow = 0;
  double _parryRecovery = 0;
  double _counterWindow = 0;
  double _facing = 1;
  double _dashRemaining = 0;
  double _dashCooldown = 0;
  double _dashContactImmunity = 0;
  double _dashDirection = 1;
  int _airJumpsRemaining = 1;
  String? lastDamageCauseId;

  bool get canAttack => _attackCooldown <= 0 && !isRemoving;
  bool get canParry => _parryRecovery <= 0 && !isRemoving;
  bool get isParrying => _parryWindow > 0;
  bool get hasParryCounter => _counterWindow > 0;
  bool get isInvulnerable => _hitInvulnerability > 0;
  bool get isMoving => _usesPlatformerMovement
      ? _platformerMotion.velocity.length2 > 0.01
      : _movementInput.length2 > 0.01;
  int get dataShardCharge => _dataShardCharge;
  double get facingDirection => _facing;
  double get dashCooldownRemaining => _dashCooldown;
  double get dashCooldownProgress =>
      (_dashCooldown / dashCooldownSeconds).clamp(0, 1);
  int get airJumpsRemaining =>
      selectedWeapon == PlayerWeapon.gauntlet ? _airJumpsRemaining : 0;
  bool get isDashing => _dashRemaining > 0;
  bool get hasCompleteArtV3Visuals => PlayerWeapon.values.every(
    (weapon) =>
        _weaponLocomotionFrames[weapon]?.length ==
            PlayerAnimationState.values.length &&
        _weaponCombatFrames[weapon]?.length ==
            PlayerCombatAnimation.values.length,
  );

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
    final moveImage = await game.images.load(
      'sprites/animations/qa-hero-move.png',
    );
    final pulseImage = await game.images.load(
      'sprites/animations/qa-hero-pulse.png',
    );
    final hurtImage = await game.images.load(
      'sprites/animations/qa-hero-hurt.png',
    );
    if (isRemoving) return;
    _idleFrames = _frames(idleImage, 4);
    _moveFrames = _frames(moveImage, 6);
    _pulseFrames = _frames(pulseImage, 4);
    _hurtFrames = _frames(hurtImage, 3);
    visual.setDefaultAnimation(_idleFrames!, fps: 6);
    for (final weapon in PlayerWeapon.values) {
      final image = await game.images.load(
        'sprites/combat_v2/hero/${weapon.assetName}.png',
      );
      _weaponFrames[weapon] = _frames(image, 10);
      final locomotion = <PlayerAnimationState, List<Sprite>>{};
      for (final state in PlayerAnimationState.values) {
        try {
          final stateImage = await game.images.load(
            weapon.animationAssetPath(state),
          );
          locomotion[state] = _frames(stateImage, state.frameCount);
        } catch (_) {
          // Art v3 states are presentation-only. Keep the QA Hero fallback
          // alive if an individual optional strip is absent or corrupt.
        }
      }
      _weaponLocomotionFrames[weapon] = locomotion;
      final combat = <PlayerCombatAnimation, List<Sprite>>{};
      for (final state in PlayerCombatAnimation.values) {
        try {
          final stateImage = await game.images.load(
            weapon.combatAnimationAssetPath(state),
          );
          combat[state] = _frames(stateImage, state.frameCount);
        } catch (_) {
          // Each Art v3 strip is optional so one damaged file cannot prevent
          // the remaining authored combat motions from loading.
        }
      }
      _weaponCombatFrames[weapon] = combat;
    }
    final gauntletSpin = await game.images.load(
      'sprites/abilities/gauntlet-double-jump-spin.png',
    );
    final swordDash = await game.images.load(
      'sprites/abilities/sword-dash.png',
    );
    final gunRail = await game.images.load(
      'sprites/abilities/gun-charged-rail.png',
    );
    if (isRemoving) return;
    _gauntletDoubleJumpFrames = _frames(gauntletSpin, 6);
    _swordDashFrames = _frames(swordDash, 6);
    _gunRailFrames = _frames(gunRail, 6);
    _syncMovementAnimation(force: true);
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

  void setJumpHeld(bool value) => _jumpHeld = value;

  void queueJump() {
    if (!_usesPlatformerMovement) return;
    if (selectedWeapon == PlayerWeapon.gauntlet &&
        !_platformerMotion.canGroundJump &&
        _airJumpsRemaining > 0 &&
        _platformerMotion.tryAirJump()) {
      _airJumpsRemaining -= 1;
      final spinFrames = _gauntletDoubleJumpFrames;
      if (spinFrames != null) {
        _playAbilityMotion(spinFrames, weapon: PlayerWeapon.gauntlet);
      }
      _visual?.squash(seconds: 0.12);
      if (isMounted) {
        unawaited(game.audio.playJump(doubleJump: true));
        game.publishUiSnapshot(force: true);
      }
      return;
    }
    if (_platformerMotion.canGroundJump && isMounted) {
      unawaited(game.audio.playJump());
    }
    _platformerMotion.queueJump();
  }

  void resetMotionForRoomTransition() {
    _platformerMotion.reset();
    _jumpHeld = false;
    _parryWindow = 0;
    _parryRecovery = 0;
    _counterWindow = 0;
    _weaponComboStep = 0;
    _weaponComboReset = 0;
    _dashRemaining = 0;
    _dashCooldown = 0;
    _dashContactImmunity = 0;
    _airJumpsRemaining = 1;
    _activeMovementAnimation = null;
    _syncMovementAnimation(force: true);
    _visual?.resetPresentation();
  }

  void applyExternalImpulse(Vector2 impulse) {
    if (!_usesPlatformerMovement || impulse.length2 == 0) return;
    _platformerMotion.velocity.add(impulse);
    _platformerMotion.velocity.x = _platformerMotion.velocity.x.clamp(
      -360,
      360,
    );
    _platformerMotion.velocity.y = _platformerMotion.velocity.y.clamp(
      -520,
      650,
    );
  }

  bool get _usesPlatformerMovement =>
      isMounted &&
      game.mode == PatchWorldMode.campaign &&
      game.world.activeRoom is PlatformerRoomGeometry;

  void selectWeapon(PlayerWeapon weapon) {
    if (selectedWeapon == weapon) return;
    selectedWeapon = weapon;
    _weaponComboStep = 0;
    _weaponComboReset = 0;
    _syncMovementAnimation(force: true);
    final frames = _weaponFrames[weapon];
    if (frames != null) _visual?.playOnce(<Sprite>[frames.first], fps: 8);
    if (isMounted) game.publishUiSnapshot(force: true);
  }

  void configureLoadout(
    PlayerWeapon weapon, {
    required bool assistMode,
    bool restoreIntegrity = true,
  }) {
    selectWeapon(weapon);
    final nextMaximum = weapon.baseIntegrity + (assistMode ? 1 : 0);
    maxIntegrity = nextMaximum;
    integrity = restoreIntegrity
        ? nextMaximum
        : integrity.clamp(0, nextMaximum);
    _airJumpsRemaining = 1;
    _dashRemaining = 0;
    _dashCooldown = 0;
    _dashContactImmunity = 0;
    if (isMounted) game.publishUiSnapshot(force: true);
  }

  bool tryDash(double requestedDirection) {
    if (selectedWeapon != PlayerWeapon.sword ||
        !_usesPlatformerMovement ||
        _dashCooldown > 0 ||
        isDashing) {
      return false;
    }
    if (!_platformerMotion.grounded && _airJumpsRemaining <= 0) return false;
    final direction = requestedDirection.abs() > 0.05
        ? requestedDirection.sign.toDouble()
        : _facing;
    _dashDirection = direction;
    _facing = direction;
    _dashRemaining = dashDurationSeconds;
    _dashCooldown = dashCooldownSeconds;
    _dashContactImmunity = dashContactImmunitySeconds;
    if (!_platformerMotion.grounded) _airJumpsRemaining = 0;
    _visual?.flash(const Color(0xFF36E1FF), seconds: 0.10);
    _visual?.actionLunge(direction: direction, seconds: .15, travel: 20);
    final dashFrames = _swordDashFrames;
    if (dashFrames != null) {
      _playAbilityMotion(dashFrames, weapon: PlayerWeapon.sword);
    }
    if (isMounted) {
      game.patchEffects.onPlayerDashed();
      unawaited(game.audio.playSwordDash());
      game.publishUiSnapshot(force: true);
    }
    return true;
  }

  void tryAttack() {
    if (!canAttack) {
      return;
    }

    if (_usesPlatformerMovement) {
      _tryWeaponAttack();
      return;
    }
    _tryPulseAttack();
  }

  void _tryPulseAttack() {
    final survivalModifiers = game.mode == PatchWorldMode.survival
        ? game.survivalModifiers
        : null;
    final ventDamageBonus =
        survivalModifiers?.motionVentEnabled == true &&
            game.patchEffects.consumeMotionVentCharge()
        ? 2
        : 0;
    final frameDamageBonus =
        game.mode == PatchWorldMode.survival &&
            game.survivalRun.frameOverclockActive
        ? survivalModifiers?.frameOverclockDamageBonus ?? 0
        : 0;
    final redlineDamageBonus =
        game.mode == PatchWorldMode.survival && game.survivalRun.overclockActive
        ? survivalModifiers?.redlineDamageBonus ?? 0
        : 0;
    final dataSurgeDamageBonus = game.mode == PatchWorldMode.survival
        ? game.survivalRun.dataSurgeDamageBonus
        : 0;
    final criticalFlowDamageBonus = game.mode == PatchWorldMode.survival
        ? game.survivalRun.criticalFlowDamageBonus
        : 0;
    _attackCooldown =
        attackCooldownSeconds *
        (survivalModifiers?.pulseCooldownMultiplier ?? 1) *
        (game.mode == PatchWorldMode.survival
            ? game.survivalRun.overclockCooldownMultiplier
            : 1) *
        (game.mode == PatchWorldMode.survival
            ? game.survivalRun.dataSurgeCooldownMultiplier
            : 1) *
        (game.mode == PatchWorldMode.survival
            ? game.survivalRun.criticalFlowCooldownMultiplier
            : 1);
    final pulseFrames = _pulseFrames;
    if (pulseFrames != null) {
      _visual?.playOnce(pulseFrames, fps: 10);
    }
    _visual?.flash(const Color(0xFFFF8FE8), seconds: 0.10);
    _visual?.squash();
    final pulsePosition = position.clone();
    final activeRoom = game.world.activeRoom;
    final ghostVentRadiusMultiplier =
        survivalModifiers?.ghostVentFusion == true &&
            activeRoom is SurvivalArenaController &&
            activeRoom.isPhaseWindowOpen
        ? survivalModifiers!.ghostVentRadiusMultiplier
        : 1.0;
    game.world.spawnPatchPulse(
      pulsePosition,
      damage:
          (survivalModifiers?.pulseDamage ?? 1) +
          ventDamageBonus +
          frameDamageBonus +
          redlineDamageBonus +
          dataSurgeDamageBonus +
          criticalFlowDamageBonus,
      radiusMultiplier:
          (survivalModifiers?.pulseRadiusMultiplier ?? 1) *
          ghostVentRadiusMultiplier,
    );
    game.patchEffects.onPatchPulseEmitted(
      pulsePosition,
      retaliationEchoTier: survivalModifiers?.retaliationEchoTier ?? 0,
    );
    unawaited(game.audio.playPatchPulse());
  }

  void _tryWeaponAttack() {
    final counter = _counterWindow > 0;
    final motionIndex = counter ? 9 : 1 + _weaponComboStep;
    _weaponComboStep = counter ? 0 : (_weaponComboStep + 1) % 6;
    _weaponComboReset = 0.85;
    _counterWindow = 0;
    _attackCooldown = counter ? 0.18 : selectedWeapon.baseCooldown;
    final isGunRail = selectedWeapon == PlayerWeapon.gun && motionIndex == 4;
    final railFrames = _gunRailFrames;
    if (isGunRail && railFrames != null) {
      _playAbilityMotion(
        railFrames,
        weapon: PlayerWeapon.gun,
        authoredActionFrames:
            _weaponCombatFrames[PlayerWeapon.gun]?[PlayerCombatAnimation
                .attack4],
      );
    } else {
      _playCombatMotion(
        counter
            ? PlayerCombatAnimation.counter
            : PlayerCombatAnimation.attackForIndex(motionIndex),
        fallbackIndex: motionIndex,
        fallbackFps: counter ? 16 : 13,
      );
    }
    _visual?.actionLunge(
      direction: _facing,
      seconds: counter ? .28 : .22,
      travel: switch (selectedWeapon) {
        PlayerWeapon.sword => counter ? 16 : 10,
        PlayerWeapon.gauntlet => counter ? 18 : 12,
        PlayerWeapon.gun => counter ? 7 : 4,
      },
    );
    _visual?.flash(
      counter ? const Color(0xFFFFD35A) : const Color(0xFF8CF5FF),
      seconds: counter ? 0.16 : 0.08,
    );

    final damage = counter
        ? 3
        : switch (selectedWeapon) {
            PlayerWeapon.sword => motionIndex == 4 || motionIndex == 6 ? 2 : 1,
            PlayerWeapon.gauntlet => motionIndex >= 3 ? 2 : 1,
            PlayerWeapon.gun => motionIndex == 4 ? 2 : 1,
          };
    switch (selectedWeapon) {
      case PlayerWeapon.sword:
        game.world.add(
          PlayerStrikeComponent(
            position: position + Vector2(_facing * 38, -2),
            size: Vector2(counter ? 112 : 72, counter ? 58 : 42),
            sourceId: counter
                ? 'player.sword.parryCounter'
                : 'player.sword.combo.$motionIndex',
            damage: damage,
            activeSeconds: counter ? 0.18 : 0.12,
            strikeColor: counter
                ? const Color(0xAAFFD35A)
                : const Color(0x8836E1FF),
          ),
        );
      case PlayerWeapon.gauntlet:
        if (motionIndex == 6 || counter) {
          game.world.add(
            PlayerStrikeComponent(
              position: position + Vector2(_facing * 24, 12),
              size: Vector2(counter ? 104 : 82, counter ? 72 : 54),
              sourceId: counter
                  ? 'player.gauntlet.parryCounter'
                  : 'player.gauntlet.groundSlam',
              damage: damage,
              activeSeconds: counter ? 0.20 : 0.16,
              strikeColor: counter
                  ? const Color(0xAAFFD35A)
                  : const Color(0x99FF4FD8),
            ),
          );
        } else {
          game.world.add(
            PlayerStrikeComponent(
              position: position + Vector2(_facing * 29, 0),
              size: Vector2(52, 38),
              sourceId: 'player.gauntlet.combo.$motionIndex',
              damage: damage,
              activeSeconds: 0.11,
              strikeColor: const Color(0x99FF4FD8),
            ),
          );
        }
      case PlayerWeapon.gun:
        final shots = counter ? 3 : (motionIndex == 3 ? 3 : 1);
        for (var index = 0; index < shots; index += 1) {
          final spread = (index - (shots - 1) / 2) * 0.12;
          game.world.add(
            PlayerProjectileComponent(
              position: position + Vector2(_facing * 26, -3),
              velocity: Vector2(_facing * (counter ? 460 : 360), spread * 360),
              sourceId: counter
                  ? 'player.gun.parryCounter'
                  : 'player.gun.combo.$motionIndex',
              damage: damage,
              projectileColor: counter
                  ? const Color(0xFFFFD35A)
                  : motionIndex == 4
                  ? const Color(0xFFFF4FD8)
                  : const Color(0xFF36E1FF),
              radius: counter ? 8 : 6,
            ),
          );
        }
    }
    game.patchEffects.onPatchPulseEmitted(position.clone());
    unawaited(
      game.audio.playWeaponAttack(
        selectedWeapon,
        heavy: counter || isGunRail || motionIndex == 6,
      ),
    );
  }

  void tryParry() {
    if (!canParry || !_usesPlatformerMovement) return;
    _parryWindow = parryWindowSeconds;
    _parryRecovery = parryRecoverySeconds;
    _playCombatMotion(
      PlayerCombatAnimation.parry,
      fallbackIndex: 7,
      fallbackFps: 12,
    );
    _visual?.flash(const Color(0xFFFFE39A), seconds: 0.12);
  }

  bool resolveIncomingAttack(ReflectableAttack attack) {
    if (!isParrying || !attack.attackTier.canBeParried || attack.isReflected) {
      return false;
    }
    if (!attack.reflectFrom(position)) return false;
    _parryWindow = 0;
    _parryRecovery = 0.18;
    _counterWindow = 1.2;
    _hitInvulnerability = math.max(_hitInvulnerability, 0.20);
    _playCombatMotion(
      PlayerCombatAnimation.perfectParry,
      fallbackIndex: 8,
      fallbackFps: 18,
    );
    _visual?.flash(const Color(0xFFFFD35A), seconds: 0.22);
    _visual?.squash(seconds: 0.16);
    if (isMounted) {
      game.triggerImpactFeedback();
      unawaited(game.audio.playHeal());
      game.publishUiSnapshot(force: true);
    }
    return true;
  }

  void _playCombatMotion(
    PlayerCombatAnimation state, {
    required int fallbackIndex,
    required double fallbackFps,
  }) {
    final frames = _weaponCombatFrames[selectedWeapon]?[state];
    if (frames != null) {
      _visual?.playOnce(frames, fps: state.fps(selectedWeapon));
      return;
    }
    _playWeaponMotion(fallbackIndex, fps: fallbackFps);
  }

  void _playAbilityMotion(
    List<Sprite> abilityFrames, {
    required PlayerWeapon weapon,
    List<Sprite>? authoredActionFrames,
  }) {
    final state = PlayerCombatAnimation.abilityTransition;
    final connector = _weaponCombatFrames[weapon]?[state];
    final frames = composeAbilityMotionFrames<Sprite>(
      abilityFrames: abilityFrames,
      transitionFrames: connector,
      authoredActionFrames: authoredActionFrames,
    );
    _visual?.playOnce(frames, fps: state.fps(weapon));
  }

  void _playWeaponMotion(int index, {required double fps}) {
    final frames = _weaponFrames[selectedWeapon];
    if (frames == null || index < 0 || index >= frames.length) return;
    final ready = frames.first;
    final sequence = switch (index) {
      7 => <Sprite>[ready, frames[7], frames[7], ready],
      8 => <Sprite>[frames[7], frames[8], frames[8], ready],
      9 => <Sprite>[ready, frames[9], frames[9], ready],
      _ => <Sprite>[ready, frames[index], frames[index], ready],
    };
    _visual?.playOnce(sequence, fps: fps);
  }

  void tryInteract() {
    game.world.tryInteract(this);
  }

  void takeDamage(int amount, {String causeId = 'unknown'}) {
    if (isMounted &&
        game.mode == PatchWorldMode.survival &&
        PatchWorldGame.survivalQaInvincible) {
      return;
    }
    final activeRoom = isMounted ? game.world.activeRoom : null;
    if (isMounted &&
        game.mode == PatchWorldMode.survival &&
        game.survivalModifiers.phaseOpenGuard &&
        activeRoom is SurvivalArenaController &&
        activeRoom.isPhaseWindowOpen) {
      return;
    }
    if (amount <= 0 || isInvulnerable || integrity <= 0) {
      return;
    }

    final appliedDamage = math.min(integrity, amount);
    integrity = math.max(0, integrity - amount);
    if (isMounted) game.runMetrics.recordDamage(appliedDamage);
    if (isMounted && game.mode == PatchWorldMode.survival) {
      game.recordSurvivalHit();
    }
    if (isMounted) {
      unawaited(game.audio.playDamage());
      game.triggerImpactFeedback();
    }
    lastDamageCauseId = causeId;
    _hitInvulnerability = hitInvulnerabilitySeconds;
    final hurtFrames = _hurtFrames;
    if (hurtFrames != null) {
      _visual?.playOnce(hurtFrames, fps: 10);
    }
    _visual?.flash(const Color(0xFFFF6464), seconds: 0.18);
    _visual?.squash(seconds: 0.20);
    if (isMounted) {
      game.publishUiSnapshot();
    }
    if (integrity == 0) {
      game.handlePlayerDefeat(causeId: causeId);
    }
  }

  void absorbDataShard({int amount = 1}) {
    _dataShardCharge += math.max(1, amount);
    _attackCooldown = math.max(0, _attackCooldown - 0.08);
    _visual?.flash(const Color(0xFF36E1FF), seconds: 0.08);
    if (_dataShardCharge < 6) {
      if (isMounted) game.publishUiSnapshot(force: true);
      return;
    }

    _dataShardCharge -= 6;
    _attackCooldown = 0;
    if (integrity < maxIntegrity) integrity += 1;
    if (isMounted) {
      if (game.mode == PatchWorldMode.survival) {
        game.triggerSurvivalDataSurge(position);
      }
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
    _parryWindow = math.max(0, _parryWindow - statusDt);
    _parryRecovery = math.max(0, _parryRecovery - statusDt);
    _counterWindow = math.max(0, _counterWindow - statusDt);
    _weaponComboReset = math.max(0, _weaponComboReset - statusDt);
    _dashRemaining = math.max(0, _dashRemaining - statusDt);
    _dashCooldown = math.max(0, _dashCooldown - statusDt);
    _dashContactImmunity = math.max(0, _dashContactImmunity - statusDt);
    if (_weaponComboReset <= 0) _weaponComboStep = 0;

    _previousPosition.setFrom(position);
    final activeRoom = isMounted ? game.world.activeRoom : null;
    final phaseMoveMultiplier =
        isMounted &&
            game.mode == PatchWorldMode.survival &&
            activeRoom is SurvivalArenaController &&
            activeRoom.isPhaseWindowOpen
        ? game.survivalModifiers.phaseOpenMoveMultiplier
        : 1.0;
    final platformRoom = activeRoom is PlatformerRoomGeometry
        ? activeRoom as PlatformerRoomGeometry
        : null;
    if (platformRoom != null && _usesPlatformerMovement) {
      _updatePlatformer(statusDt, platformRoom);
    } else {
      position += _movementInput * (moveSpeed * phaseMoveMultiplier * statusDt);
      _clampToLogicalWorld();
    }
    if (_movementInput.x.abs() > 0.05) _facing = _movementInput.x.sign;
    _visual?.faceMovement(_movementInput);
    _syncMovementAnimation();
    _updateDamageBlink();
    super.update(dt);
  }

  void _updatePlatformer(double dt, PlatformerRoomGeometry room) {
    final wasGrounded = _platformerMotion.grounded;
    var remaining = math.min(dt, 0.10);
    while (remaining > 0) {
      final step = math.min(remaining, 1 / 120);
      _platformerMotion.advance(
        step,
        horizontal: _movementInput.x,
        jumpHeld: _jumpHeld,
        runSpeedMultiplier: selectedWeapon.moveSpeedMultiplier,
      );

      if (_dashRemaining > 0) {
        _platformerMotion.velocity.x =
            _dashDirection * (dashDistance / dashDurationSeconds);
      }

      final oldX = position.x;
      position.x += _platformerMotion.velocity.x * step;
      _resolvePlatformerHorizontal(room.solidBounds, oldX);

      final oldY = position.y;
      _platformerMotion.beginVerticalResolution();
      position.y += _platformerMotion.velocity.y * step;
      _resolvePlatformerVertical(room.solidBounds, oldY);
      remaining -= step;
    }

    if (!wasGrounded && _platformerMotion.grounded && isMounted) {
      unawaited(game.audio.playLand());
      _playLandingAnimation();
    }

    if (position.y > room.killPlaneY) {
      takeDamage(1, causeId: 'hazard.platformer.data-pit');
      if (integrity > 0) {
        position.setFrom(room.respawnPointFor(position));
        _platformerMotion.reset();
      }
    }
  }

  void _resolvePlatformerHorizontal(Iterable<Rect> solids, double oldX) {
    final halfWidth = size.x / 2;
    final oldLeft = oldX - halfWidth;
    final oldRight = oldX + halfWidth;
    for (final solid in solids) {
      final bounds = _boundsAt(position.x, position.y);
      if (!bounds.overlaps(solid)) continue;
      if (_platformerMotion.velocity.x > 0 && oldRight <= solid.left + 1) {
        position.x = solid.left - halfWidth;
        _platformerMotion.hitWall();
      } else if (_platformerMotion.velocity.x < 0 &&
          oldLeft >= solid.right - 1) {
        position.x = solid.right + halfWidth;
        _platformerMotion.hitWall();
      }
    }
  }

  void _resolvePlatformerVertical(Iterable<Rect> solids, double oldY) {
    final halfHeight = size.y / 2;
    final oldTop = oldY - halfHeight;
    final oldBottom = oldY + halfHeight;
    for (final solid in solids) {
      final bounds = _boundsAt(position.x, position.y);
      if (!bounds.overlaps(solid)) continue;
      if (_platformerMotion.velocity.y >= 0 && oldBottom <= solid.top + 1) {
        position.y = solid.top - halfHeight;
        _platformerMotion.land();
        _airJumpsRemaining = 1;
      } else if (_platformerMotion.velocity.y < 0 &&
          oldTop >= solid.bottom - 1) {
        position.y = solid.bottom + halfHeight;
        _platformerMotion.hitCeiling();
      }
    }
  }

  Rect _boundsAt(double centerX, double centerY) => Rect.fromCenter(
    center: Offset(centerX, centerY),
    width: size.x,
    height: size.y,
  );

  void _syncMovementAnimation({bool force = false}) {
    if (!isMounted) return;
    final state = _desiredMovementAnimation;
    if (!force && state == _activeMovementAnimation) return;
    final List<Sprite>? frames;
    final double fps;
    if (game.mode == PatchWorldMode.campaign) {
      frames =
          _weaponLocomotionFrames[selectedWeapon]?[state] ??
          (state == PlayerAnimationState.idle ? _idleFrames : _moveFrames);
      fps = state.fps;
    } else {
      frames = state == PlayerAnimationState.run ? _moveFrames : _idleFrames;
      fps = state == PlayerAnimationState.run ? 10 : 6;
    }
    if (frames == null) return;
    _activeMovementAnimation = state;
    _visual?.setDefaultAnimation(frames, fps: fps);
  }

  PlayerAnimationState get _desiredMovementAnimation {
    return resolvePlayerAnimationState(
      usesPlatformerMovement: _usesPlatformerMovement,
      grounded: _platformerMotion.grounded,
      horizontalVelocity: _platformerMotion.velocity.x,
      verticalVelocity: _platformerMotion.velocity.y,
      isMoving: isMoving,
    );
  }

  void _playLandingAnimation() {
    if (!isMounted) return;
    if (game.mode != PatchWorldMode.campaign) return;
    final frames =
        _weaponLocomotionFrames[selectedWeapon]?[PlayerAnimationState.land];
    if (frames != null) {
      _visual?.playOnceIfIdle(frames, fps: PlayerAnimationState.land.fps);
    }
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
    if (_dashContactImmunity > 0) {
      super.onCollisionStart(intersectionPoints, other);
      return;
    }
    if (other is CrawlerComponent) {
      takeDamage(1, causeId: 'enemy.crawler.contact');
    } else if (other is PlatformerEnemyComponent && other.dealsContactDamage) {
      takeDamage(1, causeId: 'enemy.${other.archetype.name}.contact');
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (var index = 0; index < PlayerWeapon.values.length; index += 1) {
      final selected = selectedWeapon.index == index;
      canvas.drawRect(
        Rect.fromLTWH(5 + index * 8, -14, 6, 4),
        Paint()
          ..color = selected
              ? const Color(0xFFFFD35A)
              : const Color(0x6636E1FF),
      );
    }
    if (isParrying || hasParryCounter) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * (hasParryCounter ? 0.72 : 0.58),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hasParryCounter ? 3 : 2
          ..color = const Color(0xFFFFD35A),
      );
    }
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
