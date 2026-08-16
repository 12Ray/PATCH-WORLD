import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('campaign prewarm ledger covers all regions and enemy art', (
    tester,
  ) async {
    final paths = PatchWorldGame.campaignPrewarmAssetPaths;
    expect(paths.where((path) => path.startsWith('rooms/')), hasLength(9));
    expect(
      paths.where((path) => path.startsWith('sprites/art_v3/enemies/')),
      hasLength(15),
    );
    expect(
      paths.where((path) => path.startsWith('sprites/combat_v2/enemies/')),
      hasLength(15),
    );
    expect(
      paths.where((path) => path.startsWith('sprites/combat_v2/projectiles/')),
      hasLength(15),
    );
    expect(paths.toSet(), hasLength(paths.length));

    await tester.runAsync(() async {
      for (final path in paths) {
        final data = await rootBundle.load('assets/images/$path');
        expect(data.lengthInBytes, greaterThan(0), reason: path);
      }
    });
  });
}
