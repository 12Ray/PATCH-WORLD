import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every story theme and motif renders all three layers', () {
    for (final theme in StoryRegionVisualTheme.values) {
      for (final motif in StoryRoomVisualMotif.values) {
        final component = StoryRoomLayersComponent(
          theme: theme,
          motif: motif,
          worldSize: Vector2(32 * 30, 32 * 18),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(() => component.render(canvas), returnsNormally);
        expect(component.hasCachedPicture, isTrue);
        expect(component.size.x % StoryRoomLayersComponent.moduleSize, 0);
        expect(component.size.y % StoryRoomLayersComponent.moduleSize, 0);

        recorder.endRecording().dispose();
      }
    }
  });

  test('story renderer exposes a deterministic three-layer contract', () {
    expect(StoryRoomLayersComponent.layerOrder, <StoryRoomVisualLayer>[
      StoryRoomVisualLayer.far,
      StoryRoomVisualLayer.middle,
      StoryRoomVisualLayer.foreground,
    ]);
    expect(StoryRoomLayersComponent.moduleSize, 32);
    expect(
      PlatformSurfaceComponent.moduleSize,
      StoryRoomLayersComponent.moduleSize,
    );
  });

  test('collidable foreground records one 32 px modular picture', () {
    final surface = PlatformSurfaceComponent(
      position: Vector2.zero(),
      size: Vector2(160, 32),
    );
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    surface.render(canvas);

    expect(surface.hasCachedArtwork, isTrue);
    expect(PlatformSurfaceComponent.moduleSize, 32);
    recorder.endRecording().dispose();
  });

  test(
    'story far layer uses the non-collidable production background',
    () async {
      final data = await rootBundle.load(
        StoryRoomLayersComponent.farBackgroundAsset,
      );

      expect(data.lengthInBytes, greaterThan(1000));
    },
  );

  test('story API contains no infinite-mode theme or motif', () {
    final publicNames = <String>[
      ...StoryRegionVisualTheme.values.map((value) => value.name),
      ...StoryRoomVisualMotif.values.map((value) => value.name),
    ];

    expect(publicNames, isNot(contains('survival')));
    expect(publicNames, isNot(contains('infinite')));
  });
}
