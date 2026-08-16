import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/weapon_build_selection_overlay.dart';
import 'package:patch_world/game/builds/weapon_build_state.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('ROOM 1 build draft fits three sword branches at 960x540', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = PatchWorldGame();
    await game.localization.load('en');
    game.pendingWeaponBuildSelection = WeaponBuildSelectionRequest(
      encounterId: 0,
      weapon: PlayerWeapon.sword,
      choices: WeaponBuildCatalog.choicesFor(PlayerWeapon.sword),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: WeaponBuildSelectionOverlay(game: game),
      ),
    );

    expect(find.text('AFTERIMAGE CIRCUIT'), findsOneWidget);
    expect(find.text('COUNTER EDGE'), findsOneWidget);
    expect(find.text('FINISHER CORE'), findsOneWidget);
    expect(find.text('SELECT'), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('SELECT').first);
    await tester.pump();
    expect(find.text('CONFIRM UPGRADE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
