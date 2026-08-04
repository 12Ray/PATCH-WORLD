import 'package:patch_world/game/rules/game_event.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_ids.dart';

final class DamageSignInvertedRule implements GameRule {
  const DamageSignInvertedRule();

  @override
  String get id => RuleIds.damageSignInverted;

  @override
  int get priority => 300;

  @override
  bool applies(GameEvent event, RuleContext context) =>
      event is DamageEvent && event.sourceFaction == EventFaction.player;

  @override
  RuleApplication apply(GameEvent event, RuleContext context) {
    final damage = event as DamageEvent;
    return RuleApplication(
      primary: HealEvent(
        sourceId: damage.sourceId,
        targetId: damage.targetId,
        sourceFaction: damage.sourceFaction,
        amount: damage.amount,
      ),
    );
  }
}
