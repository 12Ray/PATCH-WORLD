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

/// Optional zoom policy for authored room cinematics. A zoom of 1 keeps the
/// full 960x540 logical viewport visible; values below 1 reveal more world and
/// values above 1 create a tighter shot.
abstract interface class PlatformerRoomCameraZoom {
  double cameraZoomFor(Vector2 playerPosition);
}

/// Optional side-view composition policy that reveals more of the route in
/// the direction the player is facing. [PatchWorldGame] eases toward this
/// value so turning around never snaps the camera.
abstract interface class PlatformerRoomCameraLead {
  double get horizontalCameraLead;
}

/// Optional dead-zone and easing policy for large exploration rooms.
abstract interface class PlatformerRoomCameraFollow {
  double get horizontalCameraDeadZone;
  double get verticalCameraDeadZone;
  double get cameraFollowResponsiveness;
}
