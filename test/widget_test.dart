import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/patch_world_app.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('boots the fixed-resolution Flame game', (tester) async {
    await tester.pumpWidget(const PatchWorldApp());
    await tester.pump();

    final gameFinder = find.byWidgetPredicate(
      (widget) => widget is GameWidget<PatchWorldGame>,
    );
    expect(gameFinder, findsOneWidget);

    final gameWidget = tester.widget<GameWidget<PatchWorldGame>>(gameFinder);
    expect(gameWidget.autofocus, isTrue);
    expect(gameWidget.loadingBuilder, isNotNull);
    expect(gameWidget.errorBuilder, isNotNull);
    expect(gameWidget.initialActiveOverlays, contains(OverlayIds.hud));
    expect(gameWidget.overlayBuilderMap, contains(OverlayIds.pause));
    expect(gameWidget.overlayBuilderMap, contains(OverlayIds.patchSelection));
    expect(find.text('PATCH//WORLD'), findsNothing);
  });
}
