import 'package:flame/components.dart';
import 'package:flutter/services.dart';

final class InputController {
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  bool _attackQueued = false;
  bool _parryQueued = false;
  bool _interactQueued = false;
  bool _jumpQueued = false;
  int? _weaponSelectionQueued;
  Vector2 _virtualMovement = Vector2.zero();

  void syncPressedKeys(Set<LogicalKeyboardKey> keysPressed) {
    _pressedKeys
      ..clear()
      ..addAll(keysPressed);
  }

  void handleKeyDown(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyJ) {
      _attackQueued = true;
    }
    if (key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      _parryQueued = true;
    }
    if (key == LogicalKeyboardKey.digit1) _weaponSelectionQueued = 0;
    if (key == LogicalKeyboardKey.digit2) _weaponSelectionQueued = 1;
    if (key == LogicalKeyboardKey.digit3) _weaponSelectionQueued = 2;

    if (key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.enter) {
      _interactQueued = true;
    }
    if (key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.arrowUp) {
      _jumpQueued = true;
    }
  }

  void queueAttack() => _attackQueued = true;

  void queueParry() => _parryQueued = true;

  void queueWeaponSelection(int index) => _weaponSelectionQueued = index;

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
      _weaponSelectionQueued != null;

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

  int? consumeWeaponSelection() {
    final value = _weaponSelectionQueued;
    _weaponSelectionQueued = null;
    return value;
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
    _weaponSelectionQueued = null;
  }

  void clearAll() {
    _pressedKeys.clear();
    clearVirtualMovement();
    clearTransientActions();
  }

  bool _isPressed(LogicalKeyboardKey primary, LogicalKeyboardKey alternative) {
    return _pressedKeys.contains(primary) || _pressedKeys.contains(alternative);
  }
}
