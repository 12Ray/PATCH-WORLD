import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';

void main() {
  test('all four story boss arena identities render every phase safely', () {
    final identities = <BossArenaIdentity>{};
    for (final identity in <BossArenaIdentity>[
      BossArenaIdentity.overflowWarden,
      BossArenaIdentity.chronoJailer,
      BossArenaIdentity.kernelChimera,
      BossArenaIdentity.optimizer,
    ]) {
      final component = BossArenaPresentationComponent(
        size: Vector2(1440, 832),
        accentColor: const ui.Color(0xFFFFD35A),
        identity: identity,
      );
      identities.add(component.identity);
      for (final transition in <void Function()>[
        component.beginIntro,
        component.beginPhaseOne,
        component.beginPhaseTwo,
        component.beginPhaseThree,
        component.markCleared,
      ]) {
        transition();
        component.update(1 / 60);
        final recorder = ui.PictureRecorder();
        component.render(ui.Canvas(recorder));
        recorder.endRecording().dispose();
      }
      expect(component.state, BossArenaPresentationState.cleared);
    }

    expect(identities, hasLength(4));
  });
}
