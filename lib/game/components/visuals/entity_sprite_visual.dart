import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

final class SpriteFrameTransform {
  const SpriteFrameTransform({this.dx = 0, this.dy = 0, this.scale = 1});

  final double dx;
  final double dy;
  final double scale;
}

final class SpritePlaybackClip {
  SpritePlaybackClip({
    required List<Sprite> frames,
    List<SpriteFrameTransform>? frameTransforms,
  }) : frames = List<Sprite>.unmodifiable(frames),
       frameTransforms = frameTransforms == null
           ? null
           : List<SpriteFrameTransform>.unmodifiable(frameTransforms) {
    if (this.frames.isEmpty) {
      throw ArgumentError.value(frames, 'frames', 'must not be empty');
    }
    if (this.frameTransforms case final transforms?
        when transforms.length != this.frames.length) {
      throw ArgumentError.value(
        frameTransforms,
        'frameTransforms',
        'must contain one transform for every frame',
      );
    }
  }

  final List<Sprite> frames;
  final List<SpriteFrameTransform>? frameTransforms;

  bool get hasFrameTransforms =>
      frameTransforms != null && frameTransforms!.length == frames.length;
}

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
    this.animationDeltaResolver,
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
  final double Function(double rawDt)? animationDeltaResolver;

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
  List<SpriteFrameTransform>? _activeFrameTransforms;
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

  void playOnce(
    List<Sprite> frames, {
    required double fps,
    List<SpriteFrameTransform>? frameTransforms,
  }) {
    if (frames.isEmpty || fps <= 0) return;
    if (frameTransforms != null && frameTransforms.length != frames.length) {
      throw ArgumentError.value(
        frameTransforms,
        'frameTransforms',
        'must contain one transform for every frame',
      );
    }
    _startAnimation(
      frames,
      fps: fps,
      loops: false,
      frameTransforms: frameTransforms,
    );
  }

  void playClipOnce(
    SpritePlaybackClip clip, {
    required double durationSeconds,
  }) {
    if (!durationSeconds.isFinite || durationSeconds <= 0) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'must be finite and greater than zero',
      );
    }
    _startAnimation(
      clip.frames,
      fps: clip.frames.length / durationSeconds,
      loops: false,
      frameTransforms: clip.frameTransforms,
    );
  }

  /// Plays a low-priority one-shot only when no attack, ability, hurt, or
  /// other transient animation is already active.
  ///
  /// Landing uses this path so touching the floor cannot cut a meaningful
  /// combat action short. The caller can ignore the result when it only needs
  /// best-effort feedback.
  bool playOnceIfIdle(List<Sprite> frames, {required double fps}) {
    if (_activeFrames != null && !_animationLoops && _animationPlaying) {
      return false;
    }
    if (frames.isEmpty || fps <= 0) return false;
    _startAnimation(frames, fps: fps, loops: false);
    return true;
  }

  void setAnimationPlaying(bool value) {
    _animationPlaying = value;
  }

  /// Cancels a transient action without touching the gameplay component.
  /// Room changes and respawns use this to prevent a rotated or lunging pose
  /// from leaking into the next scene.
  void resetPresentation() {
    _flashRemaining = 0;
    _squashRemaining = 0;
    _actionRemaining = 0;
    position.setFrom(_basePosition);
    angle = 0;
    scale.setValues(_facing, 1);
    final defaults = _defaultFrames;
    if (defaults != null) {
      _startAnimation(defaults, fps: _defaultFps, loops: true);
    }
    _applyPaint();
  }

  void _startAnimation(
    List<Sprite> frames, {
    required double fps,
    required bool loops,
    List<SpriteFrameTransform>? frameTransforms,
  }) {
    if (frameTransforms != null && frameTransforms.length != frames.length) {
      throw ArgumentError.value(
        frameTransforms,
        'frameTransforms',
        'must contain one transform for every frame',
      );
    }
    _activeFrames = frames;
    _activeFrameTransforms = frameTransforms;
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
    final resolvedAnimationDt = animationDeltaResolver?.call(dt) ?? dt;
    _updateAnimation(
      resolvedAnimationDt.isFinite ? math.max(0, resolvedAnimationDt) : 0,
    );
    _phase += dt * bobSpeed * (1 + _motionStrength * 0.7);
    final transientAction =
        _activeFrames != null && !_animationLoops && _animationPlaying;
    final frameTransform = _activeFrameTransforms == null
        ? const SpriteFrameTransform()
        : _activeFrameTransforms![_frameIndex.clamp(
            0,
            _activeFrameTransforms!.length - 1,
          )];
    final actionProgress = _actionRemaining <= 0
        ? 0.0
        : 1 - _actionRemaining / _actionDuration;
    final actionOffset = _actionRemaining <= 0
        ? 0.0
        : math.sin(actionProgress * math.pi) * _actionTravel * _actionDirection;
    position.setValues(
      _basePosition.x + actionOffset + frameTransform.dx * _facing,
      _basePosition.y +
          frameTransform.dy +
          (transientAction ? 0 : math.sin(_phase) * bobAmplitude),
    );
    // Do not stack idle bob/rotation on top of authored combat poses. Keeping
    // the visual pivot still during one-shots removes the apparent size jump
    // and makes the actual contact frame easier to read.
    angle = transientAction ? 0 : math.sin(_phase * 0.55) * rotationAmplitude;

    if (_flashRemaining > 0) {
      _flashRemaining = math.max(0, _flashRemaining - dt);
      if (_flashRemaining == 0) _applyPaint();
    }
    if (_squashRemaining > 0) {
      _squashRemaining = math.max(0, _squashRemaining - dt);
      final progress = 1 - _squashRemaining / _squashDuration;
      final pulse = math.sin(progress * math.pi);
      scale.setValues(
        _facing * frameTransform.scale * (1 + pulse * 0.12),
        frameTransform.scale * (1 - pulse * 0.08),
      );
    } else {
      scale.setValues(_facing * frameTransform.scale, frameTransform.scale);
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
