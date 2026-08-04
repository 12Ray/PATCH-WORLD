import 'package:patch_world/game/rules/game_event.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_ids.dart';

final class DamageSignInvertedRule implements GameRule {
  const DamageSignInvertedRule({
    this.ruleId = RuleIds.damageSignInverted,
    this.rulePriority = 300,
  });

  final String ruleId;
  final int rulePriority;

  @override
  String get id => ruleId;

  @override
  int get priority => rulePriority;

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
