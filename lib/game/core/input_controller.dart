import 'package:flame/components.dart';
import 'package:flutter/services.dart';

final class InputController {
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  bool _attackQueued = false;
  bool _parryQueued = false;
  bool _interactQueued = false;
  bool _jumpQueued = false;
  double? _specialDirectionQueued;
  bool _specialReleaseQueued = false;
  bool _specialHeld = false;
  Vector2 _virtualMovement = Vector2.zero();

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
    if (!isRepeat && key == LogicalKeyboardKey.keyK) {
      queueSpecialPress(movementAxis.x);
    }
    if (key == LogicalKeyboardKey.keyL) {
      _interactQueued = true;
    }
    if (key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.arrowUp) {
      _jumpQueued = true;
    }
  }

  void handleKeyUp(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyK) queueSpecialRelease();
  }

  void queueAttack() => _attackQueued = true;

  void queueParry() => _parryQueued = true;

  void queueSpecialPress([double direction = 0]) {
    if (_specialHeld) return;
    _specialHeld = true;
    _specialDirectionQueued = direction.sign.toDouble();
  }

  void queueSpecialRelease() {
    if (!_specialHeld) return;
    _specialHeld = false;
    _specialReleaseQueued = true;
  }

  void queueInteract() => _interactQueued = true;

  void setVirtualMovement(double x, double y) {
    if (y < -0.5 && _virtualMovement.y >= -0.5) _jumpQueued = true;
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
      _specialDirectionQueued != null ||
      _specialHeld ||
      _specialReleaseQueued;

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

  double? consumeSpecialPressDirection() {
    final value = _specialDirectionQueued;
    _specialDirectionQueued = null;
    return value;
  }

  bool consumeSpecialRelease() {
    final value = _specialReleaseQueued;
    _specialReleaseQueued = false;
    return value;
  }

  bool get specialHeld => _specialHeld;

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
    _specialDirectionQueued = null;
    _specialReleaseQueued = false;
  }

  void clearAll() {
    _pressedKeys.clear();
    _specialHeld = false;
    clearVirtualMovement();
    clearTransientActions();
  }

  bool _isPressed(LogicalKeyboardKey primary, LogicalKeyboardKey alternative) {
    return _pressedKeys.contains(primary) || _pressedKeys.contains(alternative);
  }
}
