import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rules/anomalies/damage_sign_inverted_rule.dart';
import 'package:patch_world/game/rules/game_event.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_engine.dart';
import 'package:patch_world/game/rules/rule_ids.dart';

void main() {
  const context = RuleContext(
    roomId: RoomId.damageLab,
    selectedPatchIds: <String>{},
  );

  test('damage passes through when no anomaly is active', () {
    final engine = RuleEngine()..setRules(const <GameRule>[]);
    final result = engine.resolve(_playerDamage, context);
    expect(result.primary, isA<DamageEvent>());
    expect(result.appliedRuleIds, isEmpty);
  });

  test('player damage is converted to healing', () {
    final engine = RuleEngine()
      ..setRules(const <GameRule>[DamageSignInvertedRule()]);
    final result = engine.resolve(_playerDamage, context);
    expect(result.primary, isA<HealEvent>());
    expect(result.appliedRuleIds, <String>[RuleIds.damageSignInverted]);
    expect((result.primary! as HealEvent).amount, 1);
  });

  test('enemy damage is not inverted', () {
    final engine = RuleEngine()
      ..setRules(const <GameRule>[DamageSignInvertedRule()]);
    const enemyDamage = DamageEvent(
      sourceId: 'enemy-01',
      targetId: 'player.qa-0',
      sourceFaction: EventFaction.enemy,
      amount: 1,
    );
    expect(engine.resolve(enemyDamage, context).primary, isA<DamageEvent>());
  });

  test('duplicate priorities are rejected deterministically', () {
    final engine = RuleEngine();
    expect(
      () => engine.setRules(const <GameRule>[
        DamageSignInvertedRule(),
        _DuplicatePriorityRule(),
      ]),
      throwsStateError,
    );
  });
}

const _playerDamage = DamageEvent(
  sourceId: 'player.qa-0',
  targetId: 'crawler-01',
  sourceFaction: EventFaction.player,
  amount: 1,
);

final class _DuplicatePriorityRule implements GameRule {
  const _DuplicatePriorityRule();
  @override
  String get id => 'test.duplicate-priority';
  @override
  int get priority => 300;
  @override
  bool applies(GameEvent event, RuleContext context) => false;
  @override
  RuleApplication apply(GameEvent event, RuleContext context) =>
      RuleApplication(primary: event);
}
