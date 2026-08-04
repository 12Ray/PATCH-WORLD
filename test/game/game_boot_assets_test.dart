import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('boots the world with the Room 1 Tiled map', (tester) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.runAsync(game.ready);
    await tester.pump();
    expect(game.world.isReady, isTrue);
    expect(game.world.player.isMounted, isTrue);
    expect(game.world.player.integrity, 5);
  });
}
