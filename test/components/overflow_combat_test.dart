import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/rules/anomalies/damage_sign_inverted_rule.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_engine.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/combat_system.dart';

void main() {
  const context = RuleContext(
    roomId: RoomId.damageLab,
    selectedPatchIds: <String>{},
  );

  test('three inverted pulses overflow a crawler that starts at two HP', () {
    final engine = RuleEngine()
      ..setRules(const <GameRule>[DamageSignInvertedRule()]);
    final combat = CombatSystem(
      ruleEngine: engine,
      contextProvider: () => context,
    );
    final crawler = CrawlerComponent(
      entityId: 'room-one-target',
      position: Vector2.zero(),
      initialHealth: 2,
    );

    combat.applyPlayerPulse(crawler);
    combat.applyPlayerPulse(crawler);
    combat.applyPlayerPulse(crawler);

    expect(crawler.health, 5);
    expect(crawler.isOverflowing, isTrue);
  });

  test('removing inversion restores pulse damage', () {
    final engine = RuleEngine()
      ..setRules(const <GameRule>[DamageSignInvertedRule()])
      ..removeRule(RuleIds.damageSignInverted);
    final combat = CombatSystem(
      ruleEngine: engine,
      contextProvider: () => context,
    );
    final crawler = CrawlerComponent(
      entityId: 'post-patch-target',
      position: Vector2.zero(),
    );

    combat.applyPlayerPulse(crawler);

    expect(crawler.health, CrawlerComponent.maxHealth - 1);
  });
}
