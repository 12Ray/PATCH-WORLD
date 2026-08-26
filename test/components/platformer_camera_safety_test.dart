import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

void main() {
  test('camera easing cannot leave the player against the right edge', () {
    final center = clampPlatformerCameraCenterToPlayer(
      currentCenter: 1180,
      playerCoordinate: 1700,
      halfVisibleExtent: 520,
      safeInset: 130,
      minimumCenter: 520,
      maximumCenter: 1400,
    );

    expect(center, 1310);
    expect(center + 520 - 1700, greaterThanOrEqualTo(130));
  });

  test('camera safety still respects authored world bounds', () {
    expect(
      clampPlatformerCameraCenterToPlayer(
        currentCenter: 900,
        playerCoordinate: 1900,
        halfVisibleExtent: 520,
        safeInset: 130,
        minimumCenter: 520,
        maximumCenter: 1400,
      ),
      1400,
    );
  });
}
