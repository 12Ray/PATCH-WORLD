import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_upgrade_request.dart';

void main() {
  test('reroute preserves its charge when no alternative remains', () {
    final game = PatchWorldGame();
    final firstOffer = SurvivalUpgradeCatalog.choicesForLevel(2);
    final offeredIds = firstOffer.map((patch) => patch.id).toSet();
    for (final patch in SurvivalUpgradeCatalog.all) {
      if (offeredIds.contains(patch.id)) continue;
      for (var tier = 0; tier < 3; tier += 1) {
        game.survivalRun.upgradePatch(patch.id, riskTier: 1);
      }
    }
    game.pendingSurvivalUpgrade = SurvivalUpgradeRequest(
      level: 2,
      choices: firstOffer,
    );

    expect(game.canRerouteSurvivalUpgrade, isFalse);
    expect(game.rerouteSurvivalUpgrade(), isFalse);
    expect(game.survivalRun.reroutesRemaining, 1);
  });
}
