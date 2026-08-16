import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_upgrade_request.dart';

void main() {
  test('J K L map to left middle and right survival choices', () {
    expect(
      PatchWorldGame.survivalChoiceIndexForKey(LogicalKeyboardKey.keyJ),
      0,
    );
    expect(
      PatchWorldGame.survivalChoiceIndexForKey(LogicalKeyboardKey.keyK),
      1,
    );
    expect(
      PatchWorldGame.survivalChoiceIndexForKey(LogicalKeyboardKey.keyL),
      2,
    );
    expect(
      PatchWorldGame.survivalChoiceIndexForKey(LogicalKeyboardKey.keyM),
      isNull,
    );
  });

  test('K immediately installs the middle pending patch', () {
    final game = PatchWorldGame();
    game.pendingSurvivalUpgrade = const SurvivalUpgradeRequest(
      level: 2,
      choices: <PatchDefinition>[
        PatchCatalog.motionTax,
        PatchCatalog.retaliationEcho,
        PatchCatalog.hostileTurbo,
      ],
    );

    final index = PatchWorldGame.survivalChoiceIndexForKey(
      LogicalKeyboardKey.keyK,
    )!;
    expect(game.selectPendingSurvivalChoiceAt(index), isTrue);
    expect(game.survivalRun.patchTier(PatchCatalog.retaliationEcho.id), 1);
    expect(game.pendingSurvivalUpgrade, isNull);
  });
}
