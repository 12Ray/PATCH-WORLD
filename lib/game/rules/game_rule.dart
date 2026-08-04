import 'package:patch_world/game/rules/game_event.dart';
import 'package:patch_world/game/rules/rule_context.dart';

abstract interface class GameRule {
  String get id;
  int get priority;

  bool applies(GameEvent event, RuleContext context);
  RuleApplication apply(GameEvent event, RuleContext context);
}

final class RuleApplication {
  const RuleApplication({
    required this.primary,
    this.followUps = const <GameEvent>[],
  });

  final GameEvent? primary;
  final List<GameEvent> followUps;
}

final class RuleResolution {
  const RuleResolution({
    required this.primary,
    required this.followUps,
    required this.appliedRuleIds,
  });

  final GameEvent? primary;
  final List<GameEvent> followUps;
  final List<String> appliedRuleIds;
}
