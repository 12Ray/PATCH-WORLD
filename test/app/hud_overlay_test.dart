import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/hud_overlay.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/frame_burst_controller.dart';

void main() {
  testWidgets('boss HUD fits objective and concurrent patch statuses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    await game.localization.load('ko');
    game.uiSnapshot.value = const UiSnapshot(
      integrity: 5,
      maxIntegrity: 5,
      roomLabel: 'OPTIMIZATION CORE',
      anomalyLabel: '행동 패턴 분석 중',
      objectiveLabel: '목표: 터미널(E) 활성화 후 6초 내 펄스 4회 · 안정성 75/150',
      selectedPatchIds: <String>[
        'patch.motion_tax',
        'patch.frame_burst',
        'patch.duplicate_fault',
      ],
      normalizedHeat: 0.8,
      frameBurstPhase: FrameBurstPhase.active,
      bossHealth: 6,
      bossMaxHealth: 20,
      bossStability: 75,
      bossPhase: 'perfect',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
          child: HudOverlay(game: game),
        ),
      ),
    );

    expect(find.textContaining('OPTIMIZATION CORE'), findsOneWidget);
    expect(find.textContaining('75/150'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
