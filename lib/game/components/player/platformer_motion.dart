import 'dart:math' as math;

import 'package:flame/components.dart';

/// Deterministic side-view movement state kept separate from Flame collision
/// components so the feel can be tuned and tested without mounting a game.
final class PlatformerMotion {
  static const double playerCollisionBodySize = 32;
  static const double runSpeed = 190;
  static const double defaultRunAcceleration = 1200;
  static const double defaultRunDeceleration = 1600;
  static const double defaultGravity = 1100;
  static const double defaultMaximumFallSpeed = 650;
  static const double defaultJumpSpeed = 470;
  static const double defaultCoyoteSeconds = 0.10;
  static const double defaultJumpBufferSeconds = 0.12;
  static const double defaultJumpCutMultiplier = 0.45;

  PlatformerMotion({
    this.maxRunSpeed = runSpeed,
    this.runAcceleration = defaultRunAcceleration,
    this.runDeceleration = defaultRunDeceleration,
    this.gravity = defaultGravity,
    this.maxFallSpeed = defaultMaximumFallSpeed,
    this.jumpSpeed = defaultJumpSpeed,
    this.coyoteSeconds = defaultCoyoteSeconds,
    this.jumpBufferSeconds = defaultJumpBufferSeconds,
    this.jumpCutMultiplier = defaultJumpCutMultiplier,
  });

  final double maxRunSpeed;
  final double runAcceleration;
  final double runDeceleration;
  final double gravity;
  final double maxFallSpeed;
  final double jumpSpeed;
  final double coyoteSeconds;
  final double jumpBufferSeconds;
  final double jumpCutMultiplier;

  final Vector2 velocity = Vector2.zero();
  bool grounded = false;
  double _coyoteRemaining = 0;
  double _jumpBufferRemaining = 0;
  bool _jumpCutApplied = false;

  bool get canGroundJump => grounded || _coyoteRemaining > 0;

  void queueJump() {
    _jumpBufferRemaining = jumpBufferSeconds;
  }

  void advance(
    double dt, {
    required double horizontal,
    required bool jumpHeld,
    double runSpeedMultiplier = 1,
  }) {
    final clampedHorizontal = horizontal.clamp(-1.0, 1.0);
    final targetX = clampedHorizontal * maxRunSpeed * runSpeedMultiplier;
    final acceleration = clampedHorizontal.abs() > 0.01
        ? runAcceleration
        : runDeceleration;
    velocity.x = _moveTowards(velocity.x, targetX, acceleration * dt);

    if (grounded) {
      _coyoteRemaining = coyoteSeconds;
    } else {
      _coyoteRemaining = math.max(0, _coyoteRemaining - dt);
    }
    _jumpBufferRemaining = math.max(0, _jumpBufferRemaining - dt);

    if (_jumpBufferRemaining > 0 && _coyoteRemaining > 0) {
      velocity.y = -jumpSpeed;
      grounded = false;
      _coyoteRemaining = 0;
      _jumpBufferRemaining = 0;
      _jumpCutApplied = false;
    }
    if (!jumpHeld && velocity.y < 0 && !_jumpCutApplied) {
      velocity.y *= jumpCutMultiplier;
      _jumpCutApplied = true;
    }
    velocity.y = math.min(maxFallSpeed, velocity.y + gravity * dt);
  }

  bool tryAirJump({double speedMultiplier = 0.82}) {
    if (grounded || speedMultiplier <= 0) return false;
    velocity.y = -jumpSpeed * speedMultiplier;
    _coyoteRemaining = 0;
    _jumpBufferRemaining = 0;
    _jumpCutApplied = false;
    return true;
  }

  bool tryWallJump({
    required double awayDirection,
    double horizontalSpeed = 245,
    double verticalSpeedMultiplier = .92,
  }) {
    if (grounded || awayDirection == 0) return false;
    velocity
      ..x = awayDirection.sign * horizontalSpeed
      ..y = -jumpSpeed * verticalSpeedMultiplier;
    _coyoteRemaining = 0;
    _jumpBufferRemaining = 0;
    _jumpCutApplied = false;
    return true;
  }

  void beginVerticalResolution() {
    grounded = false;
  }

  void land() {
    velocity.y = 0;
    grounded = true;
    _jumpCutApplied = false;
  }

  void hitCeiling() {
    if (velocity.y < 0) velocity.y = 0;
  }

  void hitWall() => velocity.x = 0;

  void reset() {
    velocity.setZero();
    grounded = false;
    _coyoteRemaining = 0;
    _jumpBufferRemaining = 0;
    _jumpCutApplied = false;
  }

  double _moveTowards(double current, double target, double delta) {
    if ((target - current).abs() <= delta) return target;
    return current + (target > current ? delta : -delta);
  }
}
