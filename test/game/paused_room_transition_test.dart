import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/room_two_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

void main() {
  testWidgets('confirmed patch leaves paused selection and loads next room', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget(
          game: game,
          overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
            OverlayIds.patchSelection: (_, _) => const SizedBox.shrink(),
            OverlayIds.patchApplied: (_, _) => const SizedBox.shrink(),
          },
        ),
      ),
    );
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    game.openRoomOnePatchSelection();
    expect(game.paused, isTrue);

    game.selectPatch(PatchCatalog.roomOneChoices.first.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20 && !game.world.isReady; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(game.currentRoom, RoomId.temporalHall);
    expect(game.world.activeRoom, isA<RoomTwoController>());
    expect(game.world.isReady, isTrue);
    expect(game.paused, isFalse);
    expect(game.uiSnapshot.value.objectiveLabel, contains('0/5'));
    expect(game.uiSnapshot.value.objectiveLabel, contains('시간'));
    await tester.pump(const Duration(seconds: 7));
  });
}
