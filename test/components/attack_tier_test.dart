import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/attack_tier.dart';

void main() {
  test('only the gold parryable tier can be reflected', () {
    expect(AttackTier.normal.canBeParried, isFalse);
    expect(AttackTier.enhanced.canBeParried, isFalse);
    expect(AttackTier.parryable.canBeParried, isTrue);
    expect(AttackTier.values.map((tier) => tier.color).toSet(), hasLength(3));
  });
}
