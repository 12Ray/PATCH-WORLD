import 'dart:ui';

import 'package:flame/components.dart';

/// Geometry contract shared by every side-view campaign room and boss arena.
abstract interface class PlatformerRoomGeometry {
  Vector2 get playerSpawn;
  Vector2 get worldSize;
  double get killPlaneY;
  Iterable<Rect> get solidBounds;
  Vector2 respawnPointFor(Vector2 playerPosition);
}

/// Optional camera policy used by room-based maps. The returned point is
/// clamped to the room bounds by [PatchWorldGame].
abstract interface class PlatformerRoomCameraTarget {
  Vector2 cameraTargetFor(Vector2 playerPosition);
}
