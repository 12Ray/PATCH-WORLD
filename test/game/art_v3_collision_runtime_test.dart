import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rules/rule_context.dart';

import '../support/art_v3_runtime_assertion.dart';

void main() {
  testWidgets('Collision Archive loads every Art v3 runtime visual', (
    tester,
  ) async {
    await expectCampaignRoomArtV3Loaded(tester, RoomId.collisionArchive);
  });
}
