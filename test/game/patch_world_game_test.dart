import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  test('uses the 960 by 540 fixed-resolution viewport', () {
    final game = PatchWorldGame();
    final viewport = game.camera.viewport;

    expect(viewport, isA<FixedResolutionViewport>());
    expect(
      (viewport as FixedResolutionViewport).resolution,
      Vector2(PatchWorldGame.logicalWidth, PatchWorldGame.logicalHeight),
    );
  });
}
