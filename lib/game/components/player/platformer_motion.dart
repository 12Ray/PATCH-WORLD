import 'dart:math' as math;

import 'package:flame/components.dart';

/// Deterministic side-view movement state kept separate from Flame collision
/// components so the feel can be tuned and tested without mounting a game.
final class PlatformerMotion {
  PlatformerMotion({
    this.maxRunSpeed = 190,
    this.runAcceleration = 1200,
    this.runDeceleration = 1600,
    this.gravity = 1100,
    this.maxFallSpeed = 650,
    this.jumpSpeed = 420,
    this.coyoteSeconds = 0.10,
    this.jumpBufferSeconds = 0.12,
    this.jumpCutMultiplier = 0.45,
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

  void queueJump() {
    _jumpBufferRemaining = jumpBufferSeconds;
  }

  void advance(
    double dt, {
    required double horizontal,
    required bool jumpHeld,
  }) {
    final clampedHorizontal = horizontal.clamp(-1.0, 1.0);
    final targetX = clampedHorizontal * maxRunSpeed;
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
