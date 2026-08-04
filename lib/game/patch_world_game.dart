import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:patch_world/game/patch_world.dart';

final class PatchWorldGame extends FlameGame<PatchWorld> {
  PatchWorldGame()
    : super(
        world: PatchWorld(),
        camera: CameraComponent.withFixedResolution(
          width: logicalWidth,
          height: logicalHeight,
        ),
      );

  static const double logicalWidth = 960;
  static const double logicalHeight = 540;

  @override
  Color backgroundColor() => const Color(0xFF05070D);
}
