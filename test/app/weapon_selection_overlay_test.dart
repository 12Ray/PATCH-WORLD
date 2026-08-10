import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/weapon_selection_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('shows three locked starting loadouts without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    await game.localization.load('ko');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: WeaponSelectionOverlay(game: game),
      ),
    );

    expect(find.text('칼'), findsWidgets);
    expect(find.text('주먹'), findsWidgets);
    expect(find.text('총'), findsWidgets);
    expect(find.byType(FilledButton), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
