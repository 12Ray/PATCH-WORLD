import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rules/rule_context.dart';

import '../support/room_boot_assertion.dart';

void main() {
  testWidgets('loads Optimizer Core Tiled geometry', (tester) async {
    await expectTiledRoomBoot(
      tester,
      roomId: RoomId.optimizerCore,
      expectedSpawn: Vector2(480, 450),
    );
  });
}
