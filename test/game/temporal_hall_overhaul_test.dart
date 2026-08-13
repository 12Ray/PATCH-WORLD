import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/later_chapter_overhaul_assertion.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('Temporal Hall has three cells, quest, and dedicated boss', (
    tester,
  ) async {
    await expectLaterChapterOverhaul(
      tester,
      roomId: RoomId.temporalHall,
      bossKind: CampaignChapterBossKind.chronoJailer,
      questItem: RunItemId.echoClock,
      bossItem: RunItemId.temporalRelay,
    );
  });
}
