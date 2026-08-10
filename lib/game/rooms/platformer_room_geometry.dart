import 'dart:ui';

import 'package:flame/components.dart';

/// Geometry contract shared by the three side-view campaign rooms.
abstract interface class PlatformerRoomGeometry {
  Vector2 get playerSpawn;
  Vector2 get worldSize;
  double get killPlaneY;
  Iterable<Rect> get solidBounds;
  Vector2 respawnPointFor(Vector2 playerPosition);
}
