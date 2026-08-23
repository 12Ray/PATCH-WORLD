import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';

void main() {
  test('single-frame action returns to default animation', () async {
    final image = await _testImage();
    final idleA = Sprite(image, srcSize: Vector2.all(2));
    final idleB = Sprite(image, srcSize: Vector2.all(2));
    final attack = Sprite(image, srcSize: Vector2.all(2));
    final visual = EntitySpriteVisual(
      sprite: idleA,
      size: Vector2.all(16),
      parentSize: Vector2.all(32),
      bobAmplitude: 0,
      rotationAmplitude: 0,
    );

    visual.setDefaultAnimation(<Sprite>[idleA, idleB], fps: 8);
    visual.playOnce(<Sprite>[attack], fps: 10);
    expect(visual.sprite, same(attack));

    visual.update(.11);
    expect(visual.sprite, same(idleA));
  });

  test('low-priority landing cannot interrupt an active one-shot', () async {
    final image = await _testImage();
    final idle = Sprite(image, srcSize: Vector2.all(2));
    final attackA = Sprite(image, srcSize: Vector2.all(2));
    final attackB = Sprite(image, srcSize: Vector2.all(2));
    final landing = Sprite(image, srcSize: Vector2.all(2));
    final visual = EntitySpriteVisual(
      sprite: idle,
      size: Vector2.all(16),
      parentSize: Vector2.all(32),
      bobAmplitude: 0,
      rotationAmplitude: 0,
    );

    visual.setDefaultAnimation(<Sprite>[idle], fps: 6);
    visual.playOnce(<Sprite>[attackA, attackB], fps: 10);

    expect(visual.playOnceIfIdle(<Sprite>[landing], fps: 12), isFalse);
    expect(visual.sprite, same(attackA));

    visual.update(.21);
    expect(visual.sprite, same(idle));
    expect(visual.playOnceIfIdle(<Sprite>[landing], fps: 12), isTrue);
    expect(visual.sprite, same(landing));
  });

  test('action lunge adds and then clears readable travel', () async {
    final image = await _testImage();
    final sprite = Sprite(image, srcSize: Vector2.all(2));
    final visual = EntitySpriteVisual(
      sprite: sprite,
      size: Vector2.all(16),
      parentSize: Vector2.all(32),
      bobAmplitude: 0,
      rotationAmplitude: 0,
    );

    visual.actionLunge(direction: 1, seconds: .2, travel: 10);
    visual.update(.05);
    visual.update(.05);
    expect(visual.position.x, greaterThan(16));

    visual.update(.2);
    visual.update(.01);
    expect(visual.position.x, closeTo(16, .001));
  });

  test(
    'combat frame transforms stabilize pivot and return to identity',
    () async {
      final image = await _testImage();
      final idle = Sprite(image, srcSize: Vector2.all(2));
      final attackA = Sprite(image, srcSize: Vector2.all(2));
      final attackB = Sprite(image, srcSize: Vector2.all(2));
      final visual = EntitySpriteVisual(
        sprite: idle,
        size: Vector2.all(16),
        parentSize: Vector2.all(32),
        bobAmplitude: 0,
        rotationAmplitude: 0,
      );
      visual.setDefaultAnimation(<Sprite>[idle], fps: 6);
      visual.playOnce(
        <Sprite>[attackA, attackB],
        fps: 10,
        frameTransforms: const <SpriteFrameTransform>[
          SpriteFrameTransform(dx: 3, scale: .92),
          SpriteFrameTransform(dx: -2, scale: 1.08),
        ],
      );

      visual.update(.01);
      expect(visual.position.x, closeTo(19, .001));
      expect(visual.scale.y, closeTo(.92, .001));
      visual.update(.1);
      expect(visual.position.x, closeTo(14, .001));
      expect(visual.scale.y, closeTo(1.08, .001));
      visual.update(.11);
      expect(visual.sprite, same(idle));
      expect(visual.position.x, closeTo(16, .001));
      expect(visual.scale.y, closeTo(1, .001));
    },
  );

  test('typed clip rejects missing frame registration', () async {
    final image = await _testImage();
    final sprite = Sprite(image, srcSize: Vector2.all(2));

    expect(
      () => SpritePlaybackClip(
        frames: <Sprite>[sprite, sprite],
        frameTransforms: const <SpriteFrameTransform>[SpriteFrameTransform()],
      ),
      throwsArgumentError,
    );
  });

  test(
    'combat clip advances on simulation time and preserves recovery',
    () async {
      final image = await _testImage();
      final idle = Sprite(image, srcSize: Vector2.all(2));
      final attackA = Sprite(image, srcSize: Vector2.all(2));
      final attackB = Sprite(image, srcSize: Vector2.all(2));
      var simulationDt = 0.0;
      final visual = EntitySpriteVisual(
        sprite: idle,
        size: Vector2.all(16),
        parentSize: Vector2.all(32),
        bobAmplitude: 0,
        rotationAmplitude: 0,
        animationDeltaResolver: (_) => simulationDt,
      );
      visual.setDefaultAnimation(<Sprite>[idle], fps: 6);
      final clip = SpritePlaybackClip(frames: <Sprite>[attackA, attackB]);
      visual.playClipOnce(clip, durationSeconds: .2);

      visual.update(.5);
      expect(visual.sprite, same(attackA));
      simulationDt = .1;
      visual.update(.5);
      expect(visual.sprite, same(attackB));
      visual.update(.5);
      expect(visual.sprite, same(idle));
    },
  );
}

Future<Image> _testImage() async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 2, 2),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  return recorder.endRecording().toImage(2, 2);
}
