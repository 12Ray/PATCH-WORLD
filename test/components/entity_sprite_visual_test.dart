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
