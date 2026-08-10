import 'package:flame/components.dart';
import 'package:flutter/services.dart';

final class InputController {
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  bool _attackQueued = false;
  bool _parryQueued = false;
  bool _interactQueued = false;
  bool _jumpQueued = false;
  double? _dashDirectionQueued;
  double _doubleTapRemaining = 0;
  double _lastTapDirection = 0;
  Vector2 _virtualMovement = Vector2.zero();

  static const double doubleTapWindowSeconds = 0.22;

  void syncPressedKeys(Set<LogicalKeyboardKey> keysPressed) {
    _pressedKeys
      ..clear()
      ..addAll(keysPressed);
  }

  void handleKeyDown(LogicalKeyboardKey key, {bool isRepeat = false}) {
    if (key == LogicalKeyboardKey.keyJ) {
      _attackQueued = true;
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      _parryQueued = true;
    }
    if (!isRepeat &&
        (key == LogicalKeyboardKey.keyA ||
            key == LogicalKeyboardKey.arrowLeft)) {
      _recordHorizontalTap(-1);
    }
    if (!isRepeat &&
        (key == LogicalKeyboardKey.keyD ||
            key == LogicalKeyboardKey.arrowRight)) {
      _recordHorizontalTap(1);
    }
    if (!isRepeat && key == LogicalKeyboardKey.keyK) {
      queueDash(movementAxis.x);
    }
    if (key == LogicalKeyboardKey.keyL) {
      _interactQueued = true;
    }
    if (key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.arrowUp) {
      _jumpQueued = true;
    }
  }

  void queueAttack() => _attackQueued = true;

  void queueParry() => _parryQueued = true;

  void queueDash([double direction = 0]) {
    _dashDirectionQueued = direction.sign.toDouble();
  }

  void queueInteract() => _interactQueued = true;

  void setVirtualMovement(double x, double y) {
    if (y < -0.5 && _virtualMovement.y >= -0.5) _jumpQueued = true;
    if (x.abs() > 0.5 && _virtualMovement.x.abs() <= 0.5) {
      _recordHorizontalTap(x.sign.toDouble());
    }
    _virtualMovement = Vector2(x, y);
    if (_virtualMovement.length2 > 1) _virtualMovement.normalize();
  }

  void clearVirtualMovement() => _virtualMovement.setZero();

  Vector2 get movementAxis {
    double x = 0;
    double y = 0;

    if (_isPressed(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft)) {
      x -= 1;
    }
    if (_isPressed(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight)) {
      x += 1;
    }
    if (_isPressed(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)) {
      y -= 1;
    }
    if (_isPressed(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown)) {
      y += 1;
    }

    final axis = Vector2(x, y)..add(_virtualMovement);
    if (axis.length2 > 1) {
      axis.normalize();
    }
    return axis;
  }

  bool get hasGameplayIntent =>
      movementAxis.length2 > 0 ||
      _attackQueued ||
      _parryQueued ||
      _interactQueued ||
      _jumpQueued ||
      _dashDirectionQueued != null;

  bool get jumpHeld =>
      _isPressed(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp) ||
      _virtualMovement.y < -0.5;

  bool consumeJump() {
    final value = _jumpQueued;
    _jumpQueued = false;
    return value;
  }

  bool consumeAttack() {
    final value = _attackQueued;
    _attackQueued = false;
    return value;
  }

  bool consumeParry() {
    final value = _parryQueued;
    _parryQueued = false;
    return value;
  }

  double? consumeDashDirection() {
    final value = _dashDirectionQueued;
    _dashDirectionQueued = null;
    return value;
  }

  void advance(double dt) {
    if (dt <= 0) return;
    _doubleTapRemaining = (_doubleTapRemaining - dt)
        .clamp(0, double.infinity)
        .toDouble();
    if (_doubleTapRemaining == 0) _lastTapDirection = 0;
  }

  bool consumeInteract() {
    final value = _interactQueued;
    _interactQueued = false;
    return value;
  }

  void clearTransientActions() {
    _attackQueued = false;
    _parryQueued = false;
    _interactQueued = false;
    _jumpQueued = false;
    _dashDirectionQueued = null;
  }

  void clearAll() {
    _pressedKeys.clear();
    _doubleTapRemaining = 0;
    _lastTapDirection = 0;
    clearVirtualMovement();
    clearTransientActions();
  }

  bool _isPressed(LogicalKeyboardKey primary, LogicalKeyboardKey alternative) {
    return _pressedKeys.contains(primary) || _pressedKeys.contains(alternative);
  }

  void _recordHorizontalTap(double direction) {
    if (_doubleTapRemaining > 0 && _lastTapDirection == direction) {
      _dashDirectionQueued = direction;
      _doubleTapRemaining = 0;
      _lastTapDirection = 0;
      return;
    }
    _lastTapDirection = direction;
    _doubleTapRemaining = doubleTapWindowSeconds;
  }
}
