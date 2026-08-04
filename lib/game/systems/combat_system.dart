import 'package:patch_world/game/rules/game_event.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_engine.dart';

abstract interface class CombatTarget {
  String get entityId;
  void receiveDamage(int amount);
  void receiveHealing(int amount);
}

typedef PlayerDamageCommitted = void Function(CombatTarget target);

final class CombatSystem {
  CombatSystem({
    required this.ruleEngine,
    required this.contextProvider,
    this.onPlayerDamageCommitted,
  });

  final RuleEngine ruleEngine;
  final RuleContext Function() contextProvider;
  final PlayerDamageCommitted? onPlayerDamageCommitted;

  RuleResolution applyPlayerPulse(CombatTarget target) {
    final resolution = ruleEngine.resolve(
      DamageEvent(
        sourceId: 'player.qa-0',
        targetId: target.entityId,
        sourceFaction: EventFaction.player,
        amount: 1,
      ),
      contextProvider(),
    );
    _commit(resolution.primary, target);
    for (final followUp in resolution.followUps) {
      _commit(followUp, target);
    }
    return resolution;
  }

  void _commit(GameEvent? event, CombatTarget target) {
    if (event == null || event.targetId != target.entityId) {
      return;
    }
    switch (event) {
      case DamageEvent(:final amount):
        target.receiveDamage(amount);
        if (event.sourceFaction == EventFaction.player) {
          onPlayerDamageCommitted?.call(target);
        }
      case HealEvent(:final amount):
        target.receiveHealing(amount);
    }
  }
}
