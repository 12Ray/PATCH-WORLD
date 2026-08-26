import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:patch_world/game/builds/weapon_build_state.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
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
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/survival/survival_balance.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
import 'package:patch_world/services/game_settings.dart';

final class _PendingWeaponImpact {
  _PendingWeaponImpact({
    required this.remaining,
    required this.weapon,
    required this.motionIndex,
    required this.counter,
    required this.gunRail,
    required Vector2 direction,
    required this.airborne,
    required this.dashEmpowered,
  }) : direction = direction.clone();

  double remaining;
  final PlayerWeapon weapon;
  final int motionIndex;
  final bool counter;
  final bool gunRail;
  final Vector2 direction;
  final bool airborne;
  final bool dashEmpowered;
}

final class PlayerComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  PlayerComponent({required super.position, required this.spawnPosition})
    : super(
        size: Vector2.all(PlatformerMotion.playerCollisionBodySize),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x00000000),
        priority: 20,
      );

  static const double moveSpeed = 160;
  static const double presentationSize = 46;
  static const double damageHitboxScale = 0.66;
  static const double attackCooldownSeconds = 0.45;
  static const double hitInvulnerabilitySeconds = 0.70;
  static const double parryWindowSeconds = 0.20;
  static const double parryRecoverySeconds = 0.48;
  static const double dashDistance = 92;
  static const double dashDurationSeconds = 0.15;
  static const double dashCooldownSeconds = 5;
  static const double dashContactImmunitySeconds = 0.08;
  static const double gauntletMaximumChargeSeconds = 10;
  static const double gauntletMinimumBlastRadius = 54;
  static const double gauntletMaximumBlastRadius = 220;
  static const double gauntletChargeRecoverySeconds = 0.8;
  static const double gunLaserMaximumDurationSeconds = 5;
  static const double gunLaserMaximumRange = 340;
  static const double gunLaserHeight = 30;
  static const double gunLaserDamageIntervalSeconds = 0.25;
  static const double gunLaserCooldownSeconds = 5;

  static double gauntletChargeProgressFor(double seconds) =>
      (seconds / gauntletMaximumChargeSeconds).clamp(0, 1).toDouble();

  static double gauntletBlastRadiusForCharge(double seconds) {
    final easedProgress = math.sqrt(gauntletChargeProgressFor(seconds));
    return gauntletMinimumBlastRadius +
        (gauntletMaximumBlastRadius - gauntletMinimumBlastRadius) *
            easedProgress;
  }

  static int gauntletBlastDamageForCharge(double seconds) =>
      1 + (gauntletChargeProgressFor(seconds) * 5).floor();

  final Vector2 spawnPosition;
  final Vector2 _movementInput = Vector2.zero();
  final Vector2 _aimDirection = Vector2(1, 0);
  final Vector2 _visualMovement = Vector2.zero();
  final Vector2 _previousPosition = Vector2.zero();
  final PlatformerMotion _platformerMotion = PlatformerMotion();
  double _resolvedHorizontalVelocity = 0;
  bool _jumpHeld = false;

  int maxIntegrity = 5;
  int integrity = 5;

  double _attackCooldown = 0;
  double _hitInvulnerability = 0;
  int _dataShardCharge = 0;
  final Completer<void> _visualLoadAttempted = Completer<void>();
  Object? _visualLoadError;
  bool _registrationMetadataLoaded = false;
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
  final Map<PlayerWeapon, Map<PlayerCombatAnimation, SpritePlaybackClip>>
  _weaponCombatClips =
      <PlayerWeapon, Map<PlayerCombatAnimation, SpritePlaybackClip>>{};
  final Map<
    PlayerWeapon,
    Map<PlayerCombatAnimation, List<SpriteFrameTransform>>
  >
  _combatFrameTransforms =
      <PlayerWeapon, Map<PlayerCombatAnimation, List<SpriteFrameTransform>>>{};
  final Map<PlayerWeapon, List<SpriteFrameTransform>> _abilityFrameTransforms =
      <PlayerWeapon, List<SpriteFrameTransform>>{};
  final List<_PendingWeaponImpact> _pendingWeaponImpacts =
      <_PendingWeaponImpact>[];
  SpritePlaybackClip? _gauntletDoubleJumpClip;
  SpritePlaybackClip? _swordDashClip;
  SpritePlaybackClip? _gunRailClip;
  final Map<PlayerWeapon, SpritePlaybackClip> _composedAbilityClips =
      <PlayerWeapon, SpritePlaybackClip>{};
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
  double _swordDashInvulnerability = 0;
  double _dashEmpowerWindow = 0;
  double _dashDirection = 1;
  double _survivalSpecialCooldown = 0;
  bool _gauntletCharging = false;
  double _gauntletChargeSeconds = 0;
  double _gauntletChargeRecovery = 0;
  bool _gunLaserActive = false;
  double _gunLaserRemaining = 0;
  double _gunLaserDamageTimer = 0;
  double _gunLaserCooldown = 0;
  bool _specialInputHeld = false;
  double _presentationActionRemaining = 0;
  int _airJumpsRemaining = 1;
  int _traversalAirDashesRemaining = 1;
  double _wallContactDirection = 0;
  String? lastDamageCauseId;

  bool get canAttack => _attackCooldown <= 0 && !isRemoving;
  bool get hasActiveWeaponAction =>
      _attackCooldown > 0 ||
      _pendingWeaponImpacts.isNotEmpty ||
      _dashRemaining > 0 ||
      _gauntletCharging ||
      _gunLaserActive ||
      _presentationActionRemaining > 0;
  bool get canParry => _parryRecovery <= 0 && !isRemoving;
  bool get isParrying => _parryWindow > 0;
  bool get hasParryCounter => _counterWindow > 0;
  bool get isInvulnerable =>
      _hitInvulnerability > 0 || _swordDashInvulnerability > 0;
  bool get isMoving => _usesPlatformerMovement
      ? _platformerMotion.velocity.length2 > 0.01
      : _movementInput.length2 > 0.01;
  int get dataShardCharge => _dataShardCharge;
  int get dataShardThreshold =>
      isMounted && game.runItems.contains(RunItemId.echoClock) ? 5 : 6;
  double get facingDirection => _facing;
  double get dashCooldownRemaining => _dashCooldown;
  double get survivalSpecialCooldownRemaining => _survivalSpecialCooldown;
  bool get isGauntletCharging => _gauntletCharging;
  double get gauntletChargeSeconds => _gauntletChargeSeconds;
  double get gauntletChargeProgress =>
      gauntletChargeProgressFor(_gauntletChargeSeconds);
  bool get isGunLaserActive => _gunLaserActive;
  double get gunLaserRemaining => _gunLaserRemaining;
  double get gunLaserCooldownRemaining => _gunLaserCooldown;
  bool get specialAbilityReady => _isSpecialAbilityReady;
  double get campaignSpecialCooldownRemaining => switch (selectedWeapon) {
    PlayerWeapon.sword => _dashCooldown,
    PlayerWeapon.gauntlet => _gauntletChargeRecovery,
    PlayerWeapon.gun => _gunLaserCooldown,
  };
  double get effectiveDashCooldownSeconds => isMounted
      ? (game.runItems.swordDashCooldownSeconds -
                game.weaponBuild.swordDashCooldownReduction)
            .clamp(3, 5)
            .toDouble()
      : 5;
  double get effectiveAirJumpSpeedMultiplier => isMounted
      ? (game.runItems.gauntletAirJumpSpeedMultiplier +
                game.weaponBuild.gauntletAirJumpSpeedBonus)
            .clamp(.82, 1)
            .toDouble()
      : .82;
  double get dashCooldownProgress =>
      (_dashCooldown / effectiveDashCooldownSeconds).clamp(0, 1);
  int get airJumpsRemaining =>
      selectedWeapon == PlayerWeapon.gauntlet ? _airJumpsRemaining : 0;
  int get traversalAirDashesRemaining => _traversalAirDashesRemaining;
  bool get isTouchingWall => _wallContactDirection != 0;
  bool get isDashing => _dashRemaining > 0;
  bool get isGrounded => _platformerMotion.grounded;
  PlayerAnimationState get resolvedMovementAnimationState =>
      _desiredMovementAnimation;
  Rect get damageHitboxBounds => Rect.fromCenter(
    center: Offset(position.x, position.y),
    width: size.x * damageHitboxScale,
    height: size.y * damageHitboxScale,
  );
  bool get hasCompleteArtV3Visuals =>
      _visualLoadError == null &&
      _registrationMetadataLoaded &&
      _visual != null &&
      PlayerWeapon.values.every((weapon) {
        final combat = _weaponCombatClips[weapon];
        final ability = _composedAbilityClips[weapon];
        return _weaponLocomotionFrames[weapon]?.length ==
                PlayerAnimationState.values.length &&
            combat?.length == PlayerCombatAnimation.values.length &&
            combat!.values.every((clip) => clip.hasFrameTransforms) &&
            ability != null &&
            ability.hasFrameTransforms;
      });

  /// Completes after the visual pipeline either loads or falls back.
  ///
  /// Run startup awaits this future so a damaged optional asset cannot leave
  /// the weapon-selection screen hanging forever.
  Future<void> get visualLoadAttempted => _visualLoadAttempted.future;

  /// Completes only for a fully registered Art v3 presentation.
  ///
  /// Callers that can render the QA fallback should await
  /// [visualLoadAttempted] and inspect [hasCompleteArtV3Visuals] instead.
  Future<void> get visualReady async {
    await visualLoadAttempted;
    if (!hasCompleteArtV3Visuals) {
      throw StateError(
        'Player Art v3 registration did not load completely: '
        '${_visualLoadError ?? 'one or more authored clips are missing'}',
      );
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Loading starts while the title/weapon selection is open so the combat
    // cache is normally warm before input is enabled. It must not block Flame's
    // onLoad lifecycle because image decode completion can depend on a frame.
    unawaited(_loadVisual());
    await add(
      RectangleHitbox.relative(
        Vector2.all(damageHitboxScale),
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
        // Keep the authored animation source and the 32 px gameplay body
        // independent. The smaller silhouette gives the environment more
        // scale without changing jumps, collisions, or weapon reach.
        size: Vector2.all(presentationSize),
        parentSize: size,
        // Locomotion already lives in authored sprite frames. Procedural
        // sub-pixel bob/rotation made the pixel-art body shimmer while idle.
        bobAmplitude: 0,
        bobSpeed: 4.2,
        rotationAmplitude: 0,
        animationDeltaResolver: (rawDt) =>
            isMounted ? game.clock.simulationDt : rawDt,
      );
      if (isRemoving) return;
      _visual = visual;
      add(visual);
      await _loadAnimations(visual);
      if (!hasCompleteArtV3Visuals) {
        _visualLoadError = StateError(
          'One or more player animation clips lack complete registration',
        );
        paint.color = const Color(0xFF36E1FF);
      }
    } catch (error) {
      _visualLoadError = error;
      paint.color = const Color(0xFF36E1FF);
    } finally {
      if (!_visualLoadAttempted.isCompleted) _visualLoadAttempted.complete();
    }
  }

  Future<void> _loadAnimations(EntitySpriteVisual visual) async {
    await _loadCombatFrameTransforms();
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
      final combat = <PlayerCombatAnimation, SpritePlaybackClip>{};
      for (final state in PlayerCombatAnimation.values) {
        try {
          final stateImage = await game.images.load(
            weapon.combatAnimationAssetPath(state),
          );
          combat[state] = SpritePlaybackClip(
            frames: _frames(stateImage, state.frameCount),
            frameTransforms: _combatFrameTransforms[weapon]?[state],
          );
        } catch (_) {
          // Each Art v3 strip is optional so one damaged file cannot prevent
          // the remaining authored combat motions from loading.
        }
      }
      _weaponCombatClips[weapon] = combat;
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
    _gauntletDoubleJumpClip = _abilityClip(PlayerWeapon.gauntlet, gauntletSpin);
    _swordDashClip = _abilityClip(PlayerWeapon.sword, swordDash);
    _gunRailClip = _abilityClip(PlayerWeapon.gun, gunRail);
    _composedAbilityClips[PlayerWeapon.sword] = _composeAbilityMotionClip(
      abilityClip: _swordDashClip!,
      transitionClip:
          _weaponCombatClips[PlayerWeapon.sword]?[PlayerCombatAnimation
              .abilityTransition],
    );
    _composedAbilityClips[PlayerWeapon.gauntlet] = _composeAbilityMotionClip(
      abilityClip: _gauntletDoubleJumpClip!,
      transitionClip:
          _weaponCombatClips[PlayerWeapon.gauntlet]?[PlayerCombatAnimation
              .abilityTransition],
    );
    _composedAbilityClips[PlayerWeapon.gun] = _composeAbilityMotionClip(
      abilityClip: _gunRailClip!,
      transitionClip:
          _weaponCombatClips[PlayerWeapon.gun]?[PlayerCombatAnimation
              .abilityTransition],
      authoredActionClip:
          _weaponCombatClips[PlayerWeapon.gun]?[PlayerCombatAnimation.attack4],
    );
    _syncMovementAnimation(force: true);
  }

  Future<void> _loadCombatFrameTransforms() async {
    final source = await rootBundle.loadString(
      'assets/images/sprites/art_v3/hero/manifest.json',
    );
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final combat = decoded['combat'] as Map<String, dynamic>?;
    final abilities = decoded['abilities'] as Map<String, dynamic>?;
    if (combat == null || abilities == null) {
      throw const FormatException(
        'Player manifest must contain combat and abilities registration',
      );
    }

    final parsedCombat =
        <
          PlayerWeapon,
          Map<PlayerCombatAnimation, List<SpriteFrameTransform>>
        >{};
    final parsedAbilities = <PlayerWeapon, List<SpriteFrameTransform>>{};
    for (final weapon in PlayerWeapon.values) {
      final weaponData = combat[weapon.assetName] as Map<String, dynamic>?;
      if (weaponData == null) {
        throw FormatException('Missing combat manifest for ${weapon.name}');
      }
      final states = <PlayerCombatAnimation, List<SpriteFrameTransform>>{};
      for (final state in PlayerCombatAnimation.values) {
        final sequence = weaponData[state.name] as Map<String, dynamic>?;
        if (sequence == null ||
            sequence['frames'] != state.frameCount ||
            sequence['eventFrame'] != state.eventFrame) {
          throw FormatException(
            'Invalid combat contract for ${weapon.name}.${state.name}',
          );
        }
        states[state] = _parseFrameTransforms(
          sequence,
          expectedFrames: state.frameCount,
          contractName: '${weapon.name}.${state.name}',
        );
      }
      parsedCombat[weapon] = states;

      final ability = abilities[weapon.assetName] as Map<String, dynamic>?;
      if (ability == null || ability['frames'] != 6) {
        throw FormatException('Invalid ability contract for ${weapon.name}');
      }
      parsedAbilities[weapon] = _parseFrameTransforms(
        ability,
        expectedFrames: 6,
        contractName: '${weapon.name}.ability',
      );
    }
    _combatFrameTransforms
      ..clear()
      ..addAll(parsedCombat);
    _abilityFrameTransforms
      ..clear()
      ..addAll(parsedAbilities);
    _registrationMetadataLoaded = true;
  }

  List<SpriteFrameTransform> _parseFrameTransforms(
    Map<String, dynamic> sequence, {
    required int expectedFrames,
    required String contractName,
  }) {
    final displaySize = sequence['displaySize'] as List<dynamic>?;
    final entries = sequence['frameTransforms'] as List<dynamic>?;
    if (displaySize == null ||
        displaySize.length != 2 ||
        displaySize.any((value) => value != presentationSize) ||
        entries == null ||
        entries.length != expectedFrames) {
      throw FormatException('Incomplete frame registration for $contractName');
    }
    return entries
        .map((entry) {
          final data = entry as Map<String, dynamic>;
          final dx = (data['dx'] as num?)?.toDouble();
          final dy = (data['dy'] as num?)?.toDouble();
          final scale = (data['scale'] as num?)?.toDouble();
          if (dx == null ||
              dy == null ||
              scale == null ||
              !dx.isFinite ||
              !dy.isFinite ||
              !scale.isFinite ||
              scale <= 0) {
            throw FormatException('Invalid frame transform for $contractName');
          }
          return SpriteFrameTransform(dx: dx, dy: dy, scale: scale);
        })
        .toList(growable: false);
  }

  SpritePlaybackClip _abilityClip(PlayerWeapon weapon, Image image) =>
      SpritePlaybackClip(
        frames: _frames(image, 6),
        frameTransforms: _abilityFrameTransforms[weapon],
      );

  SpritePlaybackClip _composeAbilityMotionClip({
    required SpritePlaybackClip abilityClip,
    SpritePlaybackClip? transitionClip,
    SpritePlaybackClip? authoredActionClip,
  }) {
    List<SpriteFrameTransform> transformsFor(SpritePlaybackClip clip) =>
        clip.frameTransforms ??
        List<SpriteFrameTransform>.filled(
          clip.frames.length,
          const SpriteFrameTransform(),
          growable: false,
        );

    return SpritePlaybackClip(
      frames: composeAbilityMotionFrames<Sprite>(
        abilityFrames: abilityClip.frames,
        transitionFrames: transitionClip?.frames,
        authoredActionFrames: authoredActionClip?.frames,
      ),
      frameTransforms: composeAbilityMotionFrames<SpriteFrameTransform>(
        abilityFrames: transformsFor(abilityClip),
        transitionFrames: transitionClip == null
            ? null
            : transformsFor(transitionClip),
        authoredActionFrames: authoredActionClip == null
            ? null
            : transformsFor(authoredActionClip),
      ),
    );
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
    if (input.length2 > 0.01 &&
        isMounted &&
        game.mode == PatchWorldMode.survival) {
      _aimDirection.setFrom(input.normalized());
    }
  }

  void setJumpHeld(bool value) => _jumpHeld = value;

  void setSpecialAbilityHeld(bool value) => _specialInputHeld = value;

  void queueJump() {
    if (!_usesPlatformerMovement) return;
    if (isMounted &&
        !_platformerMotion.grounded &&
        _wallContactDirection != 0 &&
        game.campaignExploration.hasTraversalAbility(
          CampaignTraversalAbility.wallJump,
        ) &&
        _platformerMotion.tryWallJump(awayDirection: -_wallContactDirection)) {
      _facing = -_wallContactDirection;
      _wallContactDirection = 0;
      _visual?.squash(seconds: .10);
      unawaited(game.audio.playJump(doubleJump: true));
      return;
    }
    if (selectedWeapon == PlayerWeapon.gauntlet &&
        !_platformerMotion.canGroundJump &&
        _airJumpsRemaining > 0 &&
        _platformerMotion.tryAirJump(
          speedMultiplier: effectiveAirJumpSpeedMultiplier,
        )) {
      _airJumpsRemaining -= 1;
      final spinClip = _gauntletDoubleJumpClip;
      if (spinClip != null) {
        _playAbilityMotion(spinClip, weapon: PlayerWeapon.gauntlet);
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
    _swordDashInvulnerability = 0;
    _dashEmpowerWindow = 0;
    _gauntletChargeRecovery = 0;
    _gunLaserCooldown = 0;
    _cancelCampaignSpecialAbility();
    _presentationActionRemaining = 0;
    _airJumpsRemaining = 1;
    _traversalAirDashesRemaining = 1;
    _wallContactDirection = 0;
    _resolvedHorizontalVelocity = 0;
    _activeMovementAnimation = null;
    _pendingWeaponImpacts.clear();
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

  bool get _usesWeaponCombat =>
      _usesPlatformerMovement ||
      (isMounted && game.mode == PatchWorldMode.survival);

  void selectWeapon(PlayerWeapon weapon) {
    if (selectedWeapon == weapon) return;
    _cancelCampaignSpecialAbility();
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
    _traversalAirDashesRemaining = 1;
    _wallContactDirection = 0;
    _dashRemaining = 0;
    _dashCooldown = 0;
    _dashContactImmunity = 0;
    _swordDashInvulnerability = 0;
    _dashEmpowerWindow = 0;
    _survivalSpecialCooldown = 0;
    _gauntletChargeRecovery = 0;
    _gunLaserCooldown = 0;
    _cancelCampaignSpecialAbility();
    _presentationActionRemaining = 0;
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
    _dashCooldown = effectiveDashCooldownSeconds;
    _dashContactImmunity = dashDurationSeconds;
    _swordDashInvulnerability = dashDurationSeconds;
    if (game.weaponBuild.tier(WeaponBuildUpgradeId.swordDashCircuit) > 0 ||
        game.runItems.enablesSwordDashEmpowerWindow) {
      _dashEmpowerWindow = 1.25;
    }
    if (!_platformerMotion.grounded) _airJumpsRemaining = 0;
    _visual?.flash(const Color(0xFF36E1FF), seconds: 0.10);
    _visual?.actionLunge(direction: direction, seconds: .15, travel: 20);
    final dashClip = _swordDashClip;
    if (dashClip != null) {
      _playAbilityMotion(dashClip, weapon: PlayerWeapon.sword);
    }
    if (isMounted) {
      game.patchEffects.onPlayerDashed();
      unawaited(game.audio.playSwordDash());
      game.publishUiSnapshot(force: true);
    }
    return true;
  }

  bool beginSpecialAbility(double requestedDirection) {
    _specialInputHeld = true;
    if (isMounted && game.mode == PatchWorldMode.survival) {
      return _trySurvivalSpecial();
    }
    switch (selectedWeapon) {
      case PlayerWeapon.sword:
        return tryDash(requestedDirection);
      case PlayerWeapon.gauntlet:
        if (_gauntletCharging || _gauntletChargeRecovery > 0 || isRemoving) {
          return false;
        }
        _gauntletCharging = true;
        _gauntletChargeSeconds = 0;
        _visual?.flash(const Color(0xFFFF4FD8), seconds: .10);
        if (isMounted) game.publishUiSnapshot(force: true);
        return true;
      case PlayerWeapon.gun:
        if (_gunLaserActive || _gunLaserCooldown > 0 || isRemoving) {
          return false;
        }
        _gunLaserActive = true;
        _gunLaserRemaining = gunLaserMaximumDurationSeconds;
        _gunLaserDamageTimer = gunLaserDamageIntervalSeconds;
        _fireGunLaserPulse();
        final clip = _gunRailClip;
        if (clip != null) {
          _playAbilityMotion(clip, weapon: PlayerWeapon.gun);
        }
        if (isMounted) {
          unawaited(game.audio.playWeaponAttack(PlayerWeapon.gun, heavy: true));
          game.publishUiSnapshot(force: true);
        }
        return true;
    }
  }

  bool trySpecialAbility(double requestedDirection) =>
      beginSpecialAbility(requestedDirection);

  void endSpecialAbility() {
    _specialInputHeld = false;
    if (_gauntletCharging) _releaseGauntletCharge();
    if (_gunLaserActive) _finishGunLaser();
  }

  void _releaseGauntletCharge() {
    if (!_gauntletCharging) return;
    final progress = gauntletChargeProgress;
    final radius = gauntletBlastRadiusForCharge(_gauntletChargeSeconds);
    final damage = gauntletBlastDamageForCharge(_gauntletChargeSeconds);
    _gauntletCharging = false;
    _gauntletChargeSeconds = 0;
    _gauntletChargeRecovery = gauntletChargeRecoverySeconds;
    if (isMounted) {
      game.world.add(
        PlayerStrikeComponent(
          position: position.clone(),
          size: Vector2.all(radius * 2),
          sourceId: 'player.gauntlet.campaign.chargeBurst',
          damage: damage,
          activeSeconds: .24,
          strikeColor: const Color(0xAAFF4FD8),
        ),
      );
      final clip = _gauntletDoubleJumpClip;
      if (clip != null) {
        _playAbilityMotion(clip, weapon: PlayerWeapon.gauntlet);
      }
      _visual?.squash(seconds: .20);
      _visual?.flash(const Color(0xFFFF8BE5), seconds: .14);
      unawaited(
        game.audio.playWeaponAttack(PlayerWeapon.gauntlet, heavy: true),
      );
      game.triggerImpactFeedback(intensity: .7 + progress * .8);
      game.publishUiSnapshot(force: true);
    }
  }

  void _finishGunLaser() {
    if (!_gunLaserActive) return;
    _gunLaserActive = false;
    _gunLaserRemaining = 0;
    _gunLaserDamageTimer = 0;
    _gunLaserCooldown = gunLaserCooldownSeconds;
    if (isMounted) game.publishUiSnapshot(force: true);
  }

  void _cancelCampaignSpecialAbility() {
    _specialInputHeld = false;
    _gauntletCharging = false;
    _gauntletChargeSeconds = 0;
    _gunLaserActive = false;
    _gunLaserRemaining = 0;
    _gunLaserDamageTimer = 0;
  }

  void _fireGunLaserPulse() {
    if (!isMounted || !_gunLaserActive) return;
    final range = _gunLaserRange;
    if (range <= 0) return;
    final direction = _facing.sign;
    game.world.add(
      PlayerStrikeComponent(
        position: position + Vector2(direction * range / 2, 0),
        size: Vector2(range, gunLaserHeight),
        sourceId: 'player.gun.campaign.channelLaser',
        damage: 1,
        activeSeconds: .10,
        strikeColor: const Color(0xAA36E1FF),
      ),
    );
  }

  double get _gunLaserRange {
    if (!isMounted) return gunLaserMaximumRange;
    final activeRoom = game.world.activeRoom;
    if (activeRoom is! PlatformerRoomGeometry) return gunLaserMaximumRange;
    final platformRoom = activeRoom as PlatformerRoomGeometry;
    var range = gunLaserMaximumRange;
    final top = position.y - gunLaserHeight / 2;
    final bottom = position.y + gunLaserHeight / 2;
    for (final solid in platformRoom.solidBounds) {
      if (solid.bottom <= top || solid.top >= bottom) continue;
      final distance = _facing >= 0
          ? solid.left - position.x
          : position.x - solid.right;
      if (distance >= 0) range = math.min(range, distance);
    }
    return range.clamp(0, gunLaserMaximumRange).toDouble();
  }

  bool _trySurvivalSpecial() {
    if (_survivalSpecialCooldown > 0 || isRemoving) return false;
    final direction = _aimDirection.length2 == 0
        ? Vector2(_facing, 0)
        : _aimDirection.normalized();
    _survivalSpecialCooldown =
        game.survivalWeaponBuild.specialCooldownFor(selectedWeapon) *
        game.survivalItems.specialCooldownMultiplierFor(selectedWeapon);
    switch (selectedWeapon) {
      case PlayerWeapon.sword:
        final distance =
            game.survivalWeaponBuild.swordSpecialDistance +
            game.survivalItems.swordSpecialDistanceBonus;
        final start = position.clone();
        position += direction * distance;
        _clampToLogicalWorld();
        final travelled = position.distanceTo(start);
        game.world.add(
          PlayerStrikeComponent(
            position: (start + position) / 2,
            size: Vector2(travelled + 62, 68),
            rotation: math.atan2(direction.y, direction.x),
            sourceId: 'player.sword.survival.riftDash',
            damage:
                game.survivalWeaponBuild.swordSpecialDamage +
                game.survivalItems.swordSpecialDamageBonus,
            activeSeconds: 0.18,
            strikeColor: const Color(0xAA36E1FF),
          ),
        );
        _visual?.actionLunge(
          direction: direction.x.abs() < .05 ? _facing : direction.x.sign,
          seconds: .16,
          travel: 24,
        );
        final clip = _swordDashClip;
        if (clip != null) {
          _playAbilityMotion(clip, weapon: PlayerWeapon.sword);
        }
        game.patchEffects.onPlayerDashed();
        unawaited(game.audio.playSwordDash());
      case PlayerWeapon.gauntlet:
        final radius =
            game.survivalWeaponBuild.gauntletQuakeRadius +
            game.survivalItems.gauntletQuakeRadiusBonus;
        game.world.add(
          PlayerStrikeComponent(
            position: position.clone(),
            size: Vector2.all(radius * 2),
            sourceId: 'player.gauntlet.survival.quakeCore',
            damage:
                game.survivalWeaponBuild.gauntletQuakeDamage +
                game.survivalItems.gauntletQuakeDamageBonus,
            activeSeconds: .24,
            strikeColor: const Color(0xAAFF4FD8),
          ),
        );
        final clip = _gauntletDoubleJumpClip;
        if (clip != null) {
          _playAbilityMotion(clip, weapon: PlayerWeapon.gauntlet);
        }
        _visual?.squash(seconds: .20);
        unawaited(
          game.audio.playWeaponAttack(PlayerWeapon.gauntlet, heavy: true),
        );
      case PlayerWeapon.gun:
        final bonusShots =
            game.survivalWeaponBuild.gunBonusShots +
            game.survivalItems.gunBonusShots;
        final shots = 5 + bonusShots * 2;
        for (var index = 0; index < shots; index += 1) {
          final spread = (index - (shots - 1) / 2) * .13;
          final shotDirection = _rotated(direction, spread);
          game.world.add(
            PlayerProjectileComponent(
              position: position + direction * 24,
              velocity:
                  shotDirection *
                  (430 *
                      game.survivalWeaponBuild.gunProjectileSpeedMultiplier *
                      game.survivalItems.gunProjectileSpeedMultiplier),
              sourceId: 'player.gun.survival.protocolVolley',
              damage: 2,
              projectileColor: const Color(0xFFFFC857),
              radius: 7,
              maxHits:
                  game.survivalWeaponBuild.gunMaxHits +
                  game.survivalItems.gunBonusHits,
              ricochetRadians:
                  game.survivalWeaponBuild.gunRicochetRadians +
                  game.survivalItems.gunRicochetRadians,
              blastRadius: game.survivalItems.explosionRadiusFor(
                PlayerWeapon.gun,
                heavy: true,
              ),
              blastDamage: game.survivalItems.explosionDamage,
            ),
          );
        }
        final clip = _gunRailClip;
        if (clip != null) {
          _playAbilityMotion(clip, weapon: PlayerWeapon.gun);
        }
        unawaited(game.audio.playWeaponAttack(PlayerWeapon.gun, heavy: true));
    }
    _visual?.flash(const Color(0xFFFFFFFF), seconds: .14);
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
    return true;
  }

  bool tryTraversalAirDash(double requestedDirection) {
    if (selectedWeapon == PlayerWeapon.gauntlet ||
        !_usesPlatformerMovement ||
        _platformerMotion.grounded ||
        _traversalAirDashesRemaining <= 0 ||
        isDashing ||
        !game.campaignExploration.hasTraversalAbility(
          CampaignTraversalAbility.airDash,
        )) {
      return false;
    }
    final direction = requestedDirection.abs() > .05
        ? requestedDirection.sign.toDouble()
        : _facing;
    _dashDirection = direction;
    _facing = direction;
    _dashRemaining = dashDurationSeconds;
    _dashContactImmunity = dashContactImmunitySeconds;
    _traversalAirDashesRemaining -= 1;
    _platformerMotion.velocity.y = 0;
    _visual?.flash(const Color(0xFF9D8CFF), seconds: .12);
    _visual?.actionLunge(direction: direction, seconds: .15, travel: 20);
    if (isMounted) {
      unawaited(game.audio.playSwordDash());
      game.publishUiSnapshot(force: true);
    }
    return true;
  }

  void tryAttack() {
    if (!canAttack) {
      return;
    }

    if (_usesWeaponCombat) {
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
    final airborne = _usesPlatformerMovement && !isGrounded;
    final dashEmpowered =
        selectedWeapon == PlayerWeapon.sword && _dashEmpowerWindow > 0;
    if (dashEmpowered) _dashEmpowerWindow = 0;
    final motionIndex = counter ? 9 : 1 + _weaponComboStep;
    _weaponComboStep = counter ? 0 : (_weaponComboStep + 1) % 6;
    _weaponComboReset = 0.85;
    _counterWindow = 0;
    final survivalCooldownMultiplier = game.mode == PatchWorldMode.survival
        ? SurvivalWeaponBaseline.forWeapon(
                selectedWeapon,
              ).attackCooldownMultiplier *
              game.survivalModifiers.pulseCooldownMultiplier *
              game.survivalRun.overclockCooldownMultiplier *
              game.survivalRun.dataSurgeCooldownMultiplier *
              game.survivalRun.criticalFlowCooldownMultiplier *
              game.survivalWeaponBuild.attackCooldownMultiplierFor(
                selectedWeapon,
              ) *
              game.survivalItems.attackCooldownMultiplierFor(selectedWeapon)
        : 1.0;
    final effectiveInterval =
        (counter ? 0.18 : selectedWeapon.baseCooldown) *
        game.runItems.attackCooldownMultiplierFor(selectedWeapon) *
        game.weaponBuild.attackCooldownMultiplierFor(selectedWeapon) *
        survivalCooldownMultiplier;
    final isGunRail = selectedWeapon == PlayerWeapon.gun && motionIndex == 4;
    final combatMotion = counter
        ? PlayerCombatAnimation.counter
        : PlayerCombatAnimation.attackForIndex(motionIndex);
    final playback = PlayerCombatPlaybackContract.forAction(
      state: combatMotion,
      effectiveIntervalSeconds: effectiveInterval,
    );
    _attackCooldown = playback.durationSeconds;
    _playCombatMotion(
      combatMotion,
      fallbackIndex: motionIndex,
      fallbackFps: counter ? 16 : 13,
      playback: playback,
    );
    final attackDirection = game.mode == PatchWorldMode.survival
        ? _aimDirection.normalized()
        : Vector2(_facing, 0);
    _visual?.actionLunge(
      direction: attackDirection.x.abs() < .05
          ? _facing
          : attackDirection.x.sign,
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

    _pendingWeaponImpacts.add(
      _PendingWeaponImpact(
        remaining: playback.impactDelaySeconds,
        weapon: selectedWeapon,
        motionIndex: motionIndex,
        counter: counter,
        gunRail: isGunRail,
        direction: attackDirection,
        airborne: airborne,
        dashEmpowered: dashEmpowered,
      ),
    );
  }

  void _resolveWeaponImpact(_PendingWeaponImpact impact) {
    final weapon = impact.weapon;
    final motionIndex = impact.motionIndex;
    final counter = impact.counter;
    final isGunRail = impact.gunRail;
    final direction = impact.direction;
    final rotation = math.atan2(direction.y, direction.x);
    final buildDamageBonus = game.weaponBuild.damageBonusFor(
      weapon: weapon,
      motionIndex: motionIndex,
      counter: counter,
      airborne: impact.airborne,
      dashEmpowered: impact.dashEmpowered,
    );

    final itemDamageBonus =
        (motionIndex == 6 && game.runItems.contains(RunItemId.overflowCapacitor)
            ? 1
            : 0) +
        game.runItems.weaponDamageBonusFor(weapon, motionIndex) +
        (game.mode == PatchWorldMode.survival
            ? game.survivalItems.damageBonusFor(
                weapon,
                motionIndex: motionIndex,
                counter: counter,
              )
            : 0);
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
    final survivalDamageBonus = game.mode == PatchWorldMode.survival
        ? (survivalModifiers!.pulseDamage - 1) +
              ventDamageBonus +
              frameDamageBonus +
              redlineDamageBonus +
              game.survivalRun.dataSurgeDamageBonus +
              game.survivalRun.criticalFlowDamageBonus +
              game.survivalWeaponBuild.damageBonusFor(
                weapon,
                motionIndex: motionIndex,
              )
        : 0;
    final damage = counter
        ? 3 +
              (game.runItems.contains(RunItemId.collisionPrism) ? 1 : 0) +
              buildDamageBonus +
              survivalDamageBonus
        : switch (weapon) {
                PlayerWeapon.sword =>
                  motionIndex == 4 || motionIndex == 6 ? 2 : 1,
                PlayerWeapon.gauntlet => motionIndex >= 3 ? 2 : 1,
                PlayerWeapon.gun => motionIndex == 4 ? 2 : 1,
              } +
              itemDamageBonus +
              buildDamageBonus +
              survivalDamageBonus;
    switch (weapon) {
      case PlayerWeapon.sword:
        game.world.add(
          PlayerStrikeComponent(
            position: position + direction * 38,
            size:
                Vector2(counter ? 112 : 72, counter ? 58 : 42) *
                (game.mode == PatchWorldMode.survival
                    ? game.survivalWeaponBuild.swordReachMultiplier *
                          game.survivalItems.swordReachMultiplier
                    : game.runItems.weaponReachMultiplierFor(
                        weapon: weapon,
                        motionIndex: motionIndex,
                        dashEmpowered: impact.dashEmpowered,
                      )),
            rotation: rotation,
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
              position: position + direction * 24,
              size:
                  Vector2(counter ? 104 : 82, counter ? 72 : 54) *
                  (game.mode == PatchWorldMode.survival
                      ? game.survivalWeaponBuild.gauntletReachMultiplier *
                            game.survivalItems.gauntletReachMultiplier
                      : game.runItems.weaponReachMultiplierFor(
                          weapon: weapon,
                          motionIndex: motionIndex,
                          dashEmpowered: impact.dashEmpowered,
                        )),
              rotation: rotation,
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
              position: position + direction * 29,
              size:
                  Vector2(52, 38) *
                  (game.mode == PatchWorldMode.survival
                      ? game.survivalWeaponBuild.gauntletReachMultiplier *
                            game.survivalItems.gauntletReachMultiplier
                      : game.runItems.weaponReachMultiplierFor(
                          weapon: weapon,
                          motionIndex: motionIndex,
                          dashEmpowered: impact.dashEmpowered,
                        )),
              rotation: rotation,
              sourceId: 'player.gauntlet.combo.$motionIndex',
              damage: damage,
              activeSeconds: 0.11,
              strikeColor: const Color(0x99FF4FD8),
            ),
          );
        }
      case PlayerWeapon.gun:
        final bonusShots = game.mode == PatchWorldMode.survival
            ? game.survivalWeaponBuild.gunBonusShots +
                  game.survivalItems.gunBonusShots
            : 0;
        final shots = counter
            ? 3 + bonusShots
            : (motionIndex == 3 ? 3 : 1) + bonusShots;
        for (var index = 0; index < shots; index += 1) {
          final spread = (index - (shots - 1) / 2) * 0.12;
          game.world.add(
            PlayerProjectileComponent(
              position: position + direction * 26,
              velocity:
                  _rotated(direction, spread) *
                  ((counter ? 460 : 360) *
                      (game.mode == PatchWorldMode.survival
                          ? game
                                    .survivalWeaponBuild
                                    .gunProjectileSpeedMultiplier *
                                game.survivalItems.gunProjectileSpeedMultiplier
                          : game.runItems.projectileSpeedMultiplierFor(
                              weapon,
                            ))),
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
              maxHits: game.mode == PatchWorldMode.survival
                  ? game.survivalWeaponBuild.gunMaxHits +
                        game.survivalItems.gunBonusHits
                  : 1 +
                        game.runItems.projectileMaxHitsBonusFor(
                          weapon,
                          motionIndex,
                        ),
              ricochetRadians: game.mode == PatchWorldMode.survival
                  ? game.survivalWeaponBuild.gunRicochetRadians +
                        game.survivalItems.gunRicochetRadians
                  : game.runItems.projectileRicochetRadiansFor(
                      weapon,
                      motionIndex,
                    ),
              blastRadius: game.mode == PatchWorldMode.survival
                  ? game.survivalItems.explosionRadiusFor(
                      PlayerWeapon.gun,
                      heavy: counter || isGunRail,
                    )
                  : 0,
              blastDamage: game.mode == PatchWorldMode.survival
                  ? game.survivalItems.explosionDamage
                  : 0,
            ),
          );
        }
    }
    if (game.mode == PatchWorldMode.survival && weapon != PlayerWeapon.gun) {
      final heavy = counter || motionIndex == 6;
      final blastRadius = game.survivalItems.explosionRadiusFor(
        weapon,
        heavy: heavy,
      );
      if (blastRadius > 0) {
        game.world.add(
          PlayerStrikeComponent(
            position: position + direction * 36,
            size: Vector2.all(blastRadius * 2),
            sourceId: 'player.${weapon.name}.itemExplosion',
            damage: game.survivalItems.explosionDamage,
            activeSeconds: .10,
            strikeColor: const Color(0x88FFC857),
          ),
        );
      }
    }
    game.patchEffects.onPatchPulseEmitted(position.clone());
    unawaited(
      game.audio.playWeaponAttack(
        weapon,
        heavy: counter || isGunRail || motionIndex == 6,
      ),
    );
  }

  Vector2 _rotated(Vector2 direction, double radians) {
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    return Vector2(
      direction.x * cosine - direction.y * sine,
      direction.x * sine + direction.y * cosine,
    );
  }

  void tryParry() {
    if (!canParry || !_usesWeaponCombat) return;
    final itemWindowMultiplier = game.mode == PatchWorldMode.survival
        ? game.survivalItems.parryWindowMultiplier
        : 1.0;
    final itemRecoveryMultiplier = game.mode == PatchWorldMode.survival
        ? game.survivalItems.parryRecoveryMultiplier
        : 1.0;
    _parryWindow = parryWindowSeconds * itemWindowMultiplier;
    _parryRecovery = parryRecoverySeconds * itemRecoveryMultiplier;
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
    if (isMounted &&
        game.mode == PatchWorldMode.survival &&
        game.survivalItems.recordPerfectParryAndShouldHeal()) {
      restoreIntegrity(1);
    }
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
    PlayerCombatPlaybackContract? playback,
  }) {
    final clip = _weaponCombatClips[selectedWeapon]?[state];
    if (clip != null) {
      final duration =
          playback?.durationSeconds ??
          clip.frames.length / state.fps(selectedWeapon);
      _presentationActionRemaining = math.max(
        _presentationActionRemaining,
        duration,
      );
      _visual?.playClipOnce(clip, durationSeconds: duration);
      return;
    }
    _presentationActionRemaining = math.max(
      _presentationActionRemaining,
      4 / fallbackFps,
    );
    _playWeaponMotion(fallbackIndex, fps: fallbackFps);
  }

  void _playAbilityMotion(
    SpritePlaybackClip abilityClip, {
    required PlayerWeapon weapon,
    SpritePlaybackClip? authoredActionClip,
  }) {
    final state = PlayerCombatAnimation.abilityTransition;
    final clip =
        _composedAbilityClips[weapon] ??
        _composeAbilityMotionClip(
          abilityClip: abilityClip,
          transitionClip: _weaponCombatClips[weapon]?[state],
          authoredActionClip: authoredActionClip,
        );
    final duration = clip.frames.length / state.fps(weapon);
    _presentationActionRemaining = math.max(
      _presentationActionRemaining,
      duration,
    );
    _visual?.playClipOnce(clip, durationSeconds: duration);
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
      game.recordSurvivalHit(causeId: causeId, amount: appliedDamage);
    }
    if (isMounted) {
      unawaited(game.audio.playDamage());
      game.triggerImpactFeedback();
    }
    lastDamageCauseId = causeId;
    _hitInvulnerability = hitInvulnerabilitySeconds;
    final hurtFrames = _hurtFrames;
    if (hurtFrames != null) {
      _presentationActionRemaining = math.max(
        _presentationActionRemaining,
        hurtFrames.length / 10,
      );
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
    final chargeThreshold = dataShardThreshold;
    if (_dataShardCharge < chargeThreshold) {
      if (isMounted) game.publishUiSnapshot(force: true);
      return;
    }

    _dataShardCharge -= chargeThreshold;
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

  void restoreIntegrity(int amount) {
    if (amount <= 0 || integrity >= maxIntegrity) return;
    integrity = math.min(maxIntegrity, integrity + amount);
    if (isMounted) {
      unawaited(game.audio.playHeal());
      game.publishUiSnapshot(force: true);
    }
  }

  void increaseMaximumIntegrity(int amount) {
    if (amount <= 0) return;
    maxIntegrity += amount;
    integrity = math.min(maxIntegrity, integrity + amount);
    if (isMounted) game.publishUiSnapshot(force: true);
  }

  @override
  void update(double dt) {
    final statusDt = isMounted ? game.clock.playerStatusDt : dt;
    final simulationDt = isMounted ? game.clock.simulationDt : dt;
    for (final impact in _pendingWeaponImpacts.toList()) {
      impact.remaining -= simulationDt;
      if (impact.remaining > 0) continue;
      _pendingWeaponImpacts.remove(impact);
      if (integrity > 0 && !isRemoving) _resolveWeaponImpact(impact);
    }
    _attackCooldown = math.max(0, _attackCooldown - simulationDt);
    _hitInvulnerability = math.max(0, _hitInvulnerability - statusDt);
    _parryWindow = math.max(0, _parryWindow - statusDt);
    _parryRecovery = math.max(0, _parryRecovery - statusDt);
    _counterWindow = math.max(0, _counterWindow - statusDt);
    _weaponComboReset = math.max(0, _weaponComboReset - statusDt);
    _dashRemaining = math.max(0, _dashRemaining - statusDt);
    _dashCooldown = math.max(0, _dashCooldown - statusDt);
    _dashContactImmunity = math.max(0, _dashContactImmunity - statusDt);
    _swordDashInvulnerability = math.max(
      0,
      _swordDashInvulnerability - statusDt,
    );
    _dashEmpowerWindow = math.max(0, _dashEmpowerWindow - statusDt);
    _survivalSpecialCooldown = math.max(0, _survivalSpecialCooldown - statusDt);
    _gauntletChargeRecovery = math.max(0, _gauntletChargeRecovery - statusDt);
    _gunLaserCooldown = math.max(0, _gunLaserCooldown - statusDt);
    _presentationActionRemaining = math.max(
      0,
      _presentationActionRemaining - simulationDt,
    );
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
    final vectorBootsMultiplier =
        isMounted && game.runItems.contains(RunItemId.vectorBoots) ? 1.05 : 1.0;
    final platformRoom = activeRoom is PlatformerRoomGeometry
        ? activeRoom as PlatformerRoomGeometry
        : null;
    if (platformRoom != null && _usesPlatformerMovement) {
      _updatePlatformer(statusDt, platformRoom);
    } else {
      _resolvedHorizontalVelocity = _movementInput.x * moveSpeed;
      position +=
          _movementInput *
          (moveSpeed * phaseMoveMultiplier * vectorBootsMultiplier * statusDt);
      _clampToLogicalWorld();
    }
    if (_movementInput.x.abs() > 0.05) _facing = _movementInput.x.sign;
    if (isMounted &&
        game.mode == PatchWorldMode.survival &&
        _movementInput.length2 > .01) {
      _aimDirection.setFrom(_movementInput.normalized());
    }
    _updateHeldSpecialAbilities(statusDt);
    if (_usesPlatformerMovement) {
      _visualMovement.setValues(_resolvedHorizontalVelocity, 0);
      _visual?.faceMovement(_visualMovement);
    } else {
      _visual?.faceMovement(_movementInput);
    }
    _syncMovementAnimation();
    _updateDamageBlink();
    super.update(dt);
  }

  void _updateHeldSpecialAbilities(double statusDt) {
    if (!_specialInputHeld) {
      if (_gauntletCharging) _releaseGauntletCharge();
      if (_gunLaserActive) _finishGunLaser();
    }
    if (_gauntletCharging) {
      _gauntletChargeSeconds = math.min(
        gauntletMaximumChargeSeconds,
        _gauntletChargeSeconds + statusDt,
      );
    }
    if (!_gunLaserActive) return;
    _gunLaserRemaining = math.max(0, _gunLaserRemaining - statusDt);
    _gunLaserDamageTimer -= statusDt;
    while (_gunLaserDamageTimer <= 0 && _gunLaserRemaining > 0) {
      _fireGunLaserPulse();
      _gunLaserDamageTimer += gunLaserDamageIntervalSeconds;
    }
    if (_gunLaserRemaining <= 0) _finishGunLaser();
  }

  void _updatePlatformer(double dt, PlatformerRoomGeometry room) {
    final wasGrounded = _platformerMotion.grounded;
    _wallContactDirection = 0;
    final surfaceRoom = room is PlatformerRoomSurfaceMotion
        ? room as PlatformerRoomSurfaceMotion
        : null;
    final supportDisplacement =
        _platformerMotion.grounded && surfaceRoom != null
        ? surfaceRoom.surfaceDisplacementFor(_boundsAt(position.x, position.y))
        : null;
    if (supportDisplacement != null) {
      final oldX = position.x;
      final oldY = position.y;
      position.add(supportDisplacement);
      if (supportDisplacement.x != 0) {
        _resolvePlatformerHorizontal(
          room.solidBounds,
          oldX,
          horizontalVelocity: supportDisplacement.x,
        );
      }
      if (supportDisplacement.y != 0) {
        _resolvePlatformerVertical(
          room.solidBounds,
          oldY,
          verticalVelocity: supportDisplacement.y,
        );
      }
    }
    var remaining = math.min(dt, 0.10);
    _resolvedHorizontalVelocity = 0;
    while (remaining > 0) {
      final step = math.min(remaining, 1 / 120);
      _platformerMotion.advance(
        step,
        horizontal: _movementInput.x,
        jumpHeld: _jumpHeld,
        runSpeedMultiplier:
            selectedWeapon.moveSpeedMultiplier *
            (game.runItems.contains(RunItemId.vectorBoots) ? 1.05 : 1),
      );

      if (_dashRemaining > 0) {
        _platformerMotion.velocity.x =
            _dashDirection * (dashDistance / dashDurationSeconds);
      }

      final surfaceVelocity = _platformerMotion.grounded && surfaceRoom != null
          ? surfaceRoom.surfaceVelocityFor(_boundsAt(position.x, position.y))
          : null;
      final horizontalVelocity =
          _platformerMotion.velocity.x + (surfaceVelocity?.x ?? 0);
      _resolvedHorizontalVelocity = horizontalVelocity;
      final oldX = position.x;
      position.x += horizontalVelocity * step;
      _resolvePlatformerHorizontal(
        room.solidBounds,
        oldX,
        horizontalVelocity: horizontalVelocity,
      );

      final oldY = position.y;
      _platformerMotion.beginVerticalResolution();
      final verticalVelocity =
          _platformerMotion.velocity.y + (surfaceVelocity?.y ?? 0);
      position.y += verticalVelocity * step;
      _resolvePlatformerVertical(
        room.solidBounds,
        oldY,
        verticalVelocity: verticalVelocity,
      );
      remaining -= step;
    }

    if (!wasGrounded && _platformerMotion.grounded && isMounted) {
      unawaited(game.audio.playLand());
      _playLandingAnimation();
    }
    if (_platformerMotion.grounded) {
      _traversalAirDashesRemaining = 1;
    }

    if (position.y > room.killPlaneY) {
      takeDamage(1, causeId: 'hazard.platformer.data-pit');
      if (integrity > 0) {
        position.setFrom(room.respawnPointFor(position));
        _platformerMotion.reset();
      }
    }
  }

  void _resolvePlatformerHorizontal(
    Iterable<Rect> solids,
    double oldX, {
    required double horizontalVelocity,
  }) {
    final halfWidth = size.x / 2;
    final oldLeft = oldX - halfWidth;
    final oldRight = oldX + halfWidth;
    for (final solid in solids) {
      final bounds = _boundsAt(position.x, position.y);
      if (!bounds.overlaps(solid)) continue;
      if (horizontalVelocity > 0 && oldRight <= solid.left + 1) {
        position.x = solid.left - halfWidth;
        _wallContactDirection = 1;
        _platformerMotion.hitWall();
      } else if (horizontalVelocity < 0 && oldLeft >= solid.right - 1) {
        position.x = solid.right + halfWidth;
        _wallContactDirection = -1;
        _platformerMotion.hitWall();
      }
    }
  }

  void _resolvePlatformerVertical(
    Iterable<Rect> solids,
    double oldY, {
    required double verticalVelocity,
  }) {
    final halfHeight = size.y / 2;
    final oldTop = oldY - halfHeight;
    final oldBottom = oldY + halfHeight;
    for (final solid in solids) {
      final bounds = _boundsAt(position.x, position.y);
      if (!bounds.overlaps(solid)) continue;
      if (verticalVelocity >= 0 && oldBottom <= solid.top + 1) {
        position.y = solid.top - halfHeight;
        _platformerMotion.land();
        _airJumpsRemaining = 1;
      } else if (verticalVelocity < 0 && oldTop >= solid.bottom - 1) {
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
    if (game.mode == PatchWorldMode.campaign ||
        game.mode == PatchWorldMode.survival) {
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
      horizontalVelocity: _resolvedHorizontalVelocity,
      currentState: _activeMovementAnimation,
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
    final activeRoom = isMounted ? game.world.activeRoom : null;
    final worldSize = activeRoom is PlatformerRoomGeometry
        ? (activeRoom as PlatformerRoomGeometry).worldSize
        : Vector2(PatchWorldGame.logicalWidth, PatchWorldGame.logicalHeight);
    position.x = position.x
        .clamp(halfWidth, worldSize.x - halfWidth)
        .toDouble();
    position.y = position.y
        .clamp(halfHeight, worldSize.y - halfHeight)
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
    if (other is CrawlerComponent && game.mode != PatchWorldMode.survival) {
      takeDamage(1, causeId: 'enemy.crawler.contact');
    } else if (other is PlatformerEnemyComponent && other.dealsContactDamage) {
      takeDamage(1, causeId: 'enemy.${other.archetype.name}.contact');
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_gauntletCharging) {
      final progress = gauntletChargeProgress;
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        20 + progress * 22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + progress * 4
          ..color = const Color(
            0xFFFF4FD8,
          ).withValues(alpha: .35 + progress * .55),
      );
    }
    if (_gunLaserActive) {
      final range = _gunLaserRange;
      final left = _facing >= 0 ? size.x / 2 : size.x / 2 - range;
      final top = size.y / 2 - gunLaserHeight / 2;
      canvas.drawRect(
        Rect.fromLTWH(left, top, range, gunLaserHeight),
        Paint()
          ..color = const Color(0x5536E1FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRect(
        Rect.fromLTWH(left, size.y / 2 - 3, range, 6),
        Paint()..color = const Color(0xDD8AEEFF),
      );
      canvas.drawRect(
        Rect.fromLTWH(left, size.y / 2 - 1, range, 2),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    // World-space status stays focused on immediate combat information.
    const healthCellWidth = 4.0;
    const healthCellGap = 1.0;
    final healthRowWidth =
        maxIntegrity * healthCellWidth + (maxIntegrity - 1) * healthCellGap;
    final healthRowLeft = (size.x - healthRowWidth) / 2;
    for (var index = 0; index < maxIntegrity; index += 1) {
      final active = index < integrity;
      canvas.drawRect(
        Rect.fromLTWH(
          healthRowLeft + index * (healthCellWidth + healthCellGap),
          -16,
          healthCellWidth,
          4,
        ),
        Paint()
          ..color = active ? const Color(0xFF36E1FF) : const Color(0x66304050),
      );
    }

    const specialBarLeft = 5.0;
    const specialBarTop = -9.0;
    const specialBarWidth = 22.0;
    const specialBarHeight = 4.0;
    final hasSpecial = _hasAvailableSpecialAbility;
    final specialReady = hasSpecial && _isSpecialAbilityReady;
    canvas.drawRect(
      const Rect.fromLTWH(
        specialBarLeft,
        specialBarTop,
        specialBarWidth,
        specialBarHeight,
      ),
      Paint()..color = const Color(0x5525304A),
    );
    final specialProgress = _specialAbilityDisplayProgress;
    if (specialProgress > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          specialBarLeft,
          specialBarTop,
          specialBarWidth * specialProgress,
          specialBarHeight,
        ),
        Paint()
          ..color = specialReady
              ? const Color(0xFFFFD35A)
              : _gauntletCharging
              ? const Color(0xFFFF4FD8)
              : const Color(0xFF36E1FF),
      );
    } else if (!hasSpecial) {
      final unavailablePaint = Paint()
        ..color = const Color(0xFF7A8498)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        const Offset(specialBarLeft + 8, specialBarTop),
        const Offset(specialBarLeft + 14, specialBarTop + specialBarHeight),
        unavailablePaint,
      );
      canvas.drawLine(
        const Offset(specialBarLeft + 14, specialBarTop),
        const Offset(specialBarLeft + 8, specialBarTop + specialBarHeight),
        unavailablePaint,
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
  }

  bool get _hasAvailableSpecialAbility {
    if (game.mode == PatchWorldMode.survival) return true;
    return true;
  }

  bool get _isSpecialAbilityReady {
    if (game.mode == PatchWorldMode.survival) {
      return _survivalSpecialCooldown <= 0;
    }
    return switch (selectedWeapon) {
      PlayerWeapon.sword =>
        _usesPlatformerMovement &&
            _dashCooldown <= 0 &&
            !isDashing &&
            (_platformerMotion.grounded || _airJumpsRemaining > 0),
      PlayerWeapon.gauntlet =>
        !_gauntletCharging && _gauntletChargeRecovery <= 0,
      PlayerWeapon.gun => !_gunLaserActive && _gunLaserCooldown <= 0,
    };
  }

  double get _specialAbilityDisplayProgress {
    if (_gauntletCharging) return gauntletChargeProgress;
    if (_gunLaserActive) {
      return (_gunLaserRemaining / gunLaserMaximumDurationSeconds).clamp(0, 1);
    }
    if (_isSpecialAbilityReady) return 1;
    return switch (selectedWeapon) {
      PlayerWeapon.sword => 1 - dashCooldownProgress,
      PlayerWeapon.gauntlet =>
        1 -
            (_gauntletChargeRecovery / gauntletChargeRecoverySeconds).clamp(
              0,
              1,
            ),
      PlayerWeapon.gun =>
        1 - (_gunLaserCooldown / gunLaserCooldownSeconds).clamp(0, 1),
    };
  }
}
