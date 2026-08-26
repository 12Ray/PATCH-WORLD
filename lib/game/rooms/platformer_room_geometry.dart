import 'dart:ui';

import 'package:flame/components.dart';

/// Keeps a followed player inside a stable screen-space safety inset even
/// while camera easing and directional lead are still catching up.
double clampPlatformerCameraCenterToPlayer({
  required double currentCenter,
  required double playerCoordinate,
  required double halfVisibleExtent,
  required double safeInset,
  required double minimumCenter,
  required double maximumCenter,
}) {
  if (!currentCenter.isFinite ||
      !playerCoordinate.isFinite ||
      !halfVisibleExtent.isFinite ||
      halfVisibleExtent <= 0 ||
      !minimumCenter.isFinite ||
      !maximumCenter.isFinite ||
      minimumCenter > maximumCenter) {
    return currentCenter;
  }
  final inset = safeInset.isFinite
      ? safeInset.clamp(0.0, halfVisibleExtent * .8)
      : 0.0;
  final playerMinimumCenter = playerCoordinate - halfVisibleExtent + inset;
  final playerMaximumCenter = playerCoordinate + halfVisibleExtent - inset;
  return currentCenter
      .clamp(playerMinimumCenter, playerMaximumCenter)
      .clamp(minimumCenter, maximumCenter)
      .toDouble();
}

/// Geometry contract shared by every side-view campaign room and boss arena.
abstract interface class PlatformerRoomGeometry {
  Vector2 get playerSpawn;
  Vector2 get worldSize;
  double get killPlaneY;
  Iterable<Rect> get solidBounds;
  Vector2 respawnPointFor(Vector2 playerPosition);
}

/// Optional two-axis support motion used by authored platforms.
///
/// The player samples this velocity while grounded and resolves the combined
/// movement through the same collision path as normal input. This keeps
/// conveyors, lifts, rewind platforms, and boss platforms attached to the
/// gameplay body instead of moving only their artwork/collision rectangle.
abstract interface class PlatformerRoomSurfaceMotion {
  /// Motion already applied to dynamic surfaces earlier in this render frame.
  /// The player consumes it once before its fixed physics substeps.
  Vector2? surfaceDisplacementFor(Rect playerBounds);

  /// Continuous surface velocity integrated during the player's fixed physics
  /// substeps. Conveyors use this while dynamic platforms use displacement.
  Vector2? surfaceVelocityFor(Rect playerBounds);
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

/// Allows authored cinematics to temporarily favor their subject over the
/// normal gameplay rule that keeps the player inside a horizontal safe area.
abstract interface class PlatformerRoomPlayerCameraSafety {
  bool get keepsPlayerInsideHorizontalSafeArea;
}
