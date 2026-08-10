import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// A sprite presentation layer that keeps gameplay hitboxes independent from
/// the visible silhouette while adding small, readable game-feel motions.
final class EntitySpriteVisual extends SpriteComponent {
  EntitySpriteVisual({
    required super.sprite,
    required super.size,
    required Vector2 parentSize,
    this.bobAmplitude = 1.4,
    this.bobSpeed = 3.4,
    this.canFlipHorizontally = true,
    this.rotationAmplitude = 0.025,
    double phaseOffset = 0,
    Vector2? offset,
  }) : _basePosition = parentSize / 2 + (offset ?? Vector2.zero()),
       _phase = phaseOffset,
       super(
         position: parentSize / 2 + (offset ?? Vector2.zero()),
         anchor: Anchor.center,
       ) {
    paint.filterQuality = FilterQuality.none;
  }

  final Vector2 _basePosition;
  final double bobAmplitude;
  final double bobSpeed;
  final bool canFlipHorizontally;
  final double rotationAmplitude;

  double _phase;
  double _flashRemaining = 0;
  double _squashRemaining = 0;
  double _squashDuration = 0.16;
  double _motionStrength = 0;
  double _actionRemaining = 0;
  double _actionDuration = 0.22;
  double _actionDirection = 1;
  double _actionTravel = 0;
  double _facing = 1;
  double _opacity = 1;
  Color? _stateTint;
  Color _flashColor = const Color(0xFFFFFFFF);
  List<Sprite>? _defaultFrames;
  List<Sprite>? _activeFrames;
  double _defaultFps = 8;
  double _secondsPerFrame = 1 / 8;
  double _animationElapsed = 0;
  int _frameIndex = 0;
  bool _animationLoops = true;
  bool _animationPlaying = true;

  void setDefaultAnimation(List<Sprite> frames, {required double fps}) {
    if (frames.isEmpty || fps <= 0) return;
    _defaultFrames = frames;
    _defaultFps = fps;
    // Movement can change during a hit or attack. Update the return state
    // without cutting the active one-shot short.
    if (_activeFrames == null || _animationLoops) {
      _startAnimation(frames, fps: fps, loops: true);
    }
  }

  void playOnce(List<Sprite> frames, {required double fps}) {
    if (frames.isEmpty || fps <= 0) return;
    _startAnimation(frames, fps: fps, loops: false);
  }

  void setAnimationPlaying(bool value) {
    _animationPlaying = value;
  }

  void _startAnimation(
    List<Sprite> frames, {
    required double fps,
    required bool loops,
  }) {
    _activeFrames = frames;
    _secondsPerFrame = 1 / fps;
    _animationElapsed = 0;
    _frameIndex = 0;
    _animationLoops = loops;
    _animationPlaying = true;
    sprite = frames.first;
  }

  void _updateAnimation(double dt) {
    final frames = _activeFrames;
    if (!_animationPlaying || frames == null) return;
    _animationElapsed += dt;
    if (frames.length == 1) {
      if (!_animationLoops && _animationElapsed >= _secondsPerFrame) {
        final defaults = _defaultFrames;
        if (defaults == null) {
          _animationPlaying = false;
        } else {
          _startAnimation(defaults, fps: _defaultFps, loops: true);
        }
      }
      return;
    }
    while (_animationElapsed >= _secondsPerFrame) {
      _animationElapsed -= _secondsPerFrame;
      if (_frameIndex + 1 < frames.length) {
        _frameIndex += 1;
      } else if (_animationLoops) {
        _frameIndex = 0;
      } else {
        final defaults = _defaultFrames;
        if (defaults == null) {
          _animationPlaying = false;
          return;
        }
        _startAnimation(defaults, fps: _defaultFps, loops: true);
        return;
      }
      sprite = frames[_frameIndex];
    }
  }

  void faceMovement(Vector2 movement) {
    _motionStrength = movement.length2 > 0.01 ? 1 : 0;
    if (canFlipHorizontally && movement.x.abs() > 0.01) {
      _facing = movement.x < 0 ? -1 : 1;
    }
  }

  void flash(Color color, {double seconds = 0.12}) {
    _flashColor = color;
    _flashRemaining = seconds;
    _applyPaint();
  }

  void squash({double seconds = 0.16}) {
    _squashDuration = math.max(0.01, seconds);
    _squashRemaining = _squashDuration;
  }

  void actionLunge({
    required double direction,
    double seconds = 0.22,
    double travel = 9,
  }) {
    _actionDuration = math.max(.05, seconds);
    _actionRemaining = _actionDuration;
    _actionDirection = direction.sign == 0 ? 1 : direction.sign;
    _actionTravel = travel;
  }

  void setStateTint(Color? color) {
    if (_stateTint == color) return;
    _stateTint = color;
    _applyPaint();
  }

  void setVisualOpacity(double value) {
    final next = value.clamp(0.0, 1.0).toDouble();
    if ((_opacity - next).abs() < 0.01) return;
    _opacity = next;
    _applyPaint();
  }

  @override
  void update(double dt) {
    _updateAnimation(dt);
    _phase += dt * bobSpeed * (1 + _motionStrength * 0.7);
    final actionProgress = _actionRemaining <= 0
        ? 0.0
        : 1 - _actionRemaining / _actionDuration;
    final actionOffset = _actionRemaining <= 0
        ? 0.0
        : math.sin(actionProgress * math.pi) * _actionTravel * _actionDirection;
    position.setValues(
      _basePosition.x + actionOffset,
      _basePosition.y + math.sin(_phase) * bobAmplitude,
    );
    angle = math.sin(_phase * 0.55) * rotationAmplitude;

    if (_flashRemaining > 0) {
      _flashRemaining = math.max(0, _flashRemaining - dt);
      if (_flashRemaining == 0) _applyPaint();
    }
    if (_squashRemaining > 0) {
      _squashRemaining = math.max(0, _squashRemaining - dt);
      final progress = 1 - _squashRemaining / _squashDuration;
      final pulse = math.sin(progress * math.pi);
      scale.setValues(_facing * (1 + pulse * 0.12), 1 - pulse * 0.08);
    } else {
      scale.setValues(_facing, 1);
    }
    if (_actionRemaining > 0) {
      _actionRemaining = math.max(0, _actionRemaining - dt);
    }
    super.update(dt);
  }

  void _applyPaint() {
    final tint = _flashRemaining > 0 ? _flashColor : _stateTint;
    paint
      ..color = Color.fromRGBO(255, 255, 255, _opacity)
      ..colorFilter = tint == null
          ? null
          : ColorFilter.mode(tint, BlendMode.modulate);
  }
}
