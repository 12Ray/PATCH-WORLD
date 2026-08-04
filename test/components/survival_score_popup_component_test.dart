import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/survival_score_popup_component.dart';

void main() {
  test('score popup rises, scales in, and expires after 0.7 seconds', () {
    final popup = SurvivalScorePopupComponent(
      position: Vector2(200, 150),
      score: 400,
      kind: SurvivalScorePopupKind.elite,
    );

    popup.update(0.1);
    expect(popup.position.y, closeTo(146.2, 0.001));
    expect(popup.scale.x, greaterThan(0.72));
    expect(popup.isExpired, isFalse);

    popup.update(0.61);
    expect(popup.age, closeTo(0.71, 0.001));
    expect(popup.isExpired, isTrue);
  });

  test('score popup preserves score text and visual kind', () {
    final popup = SurvivalScorePopupComponent(
      position: Vector2.zero(),
      score: 2050,
      kind: SurvivalScorePopupKind.miniBoss,
    );

    expect(popup.text, '+2050');
    expect(popup.score, 2050);
    expect(popup.kind, SurvivalScorePopupKind.miniBoss);
  });
}
