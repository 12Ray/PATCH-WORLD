import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rules/rule_context.dart';

import '../support/room_boot_assertion.dart';

void main() {
  testWidgets('loads Temporal Hall Tiled geometry', (tester) async {
    await expectTiledRoomBoot(
      tester,
      roomId: RoomId.temporalHall,
      expectedSpawn: Vector2(110, 270),
    );
  });
}
