import 'dart:ui';

import 'package:flame/components.dart';

/// Geometry contract shared by the three side-view campaign rooms.
abstract interface class PlatformerRoomGeometry {
  Vector2 get playerSpawn;
  Iterable<Rect> get solidBounds;
}
