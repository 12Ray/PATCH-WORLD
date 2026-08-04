import 'package:patch_world/game/rules/game_event.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';

final class RuleEngine {
  final List<GameRule> _rules = <GameRule>[];

  List<GameRule> get activeRules => List<GameRule>.unmodifiable(_rules);

  void setRules(Iterable<GameRule> rules) {
    final nextRules = rules.toList()..sort(_compareRules);
    _validateUniqueIdsAndPriorities(nextRules);
    _rules
      ..clear()
      ..addAll(nextRules);
  }

  void addRule(GameRule rule) {
    final nextRules =
        _rules.where((GameRule item) => item.id != rule.id).toList()
          ..add(rule)
          ..sort(_compareRules);
    _validateUniqueIdsAndPriorities(nextRules);
    _rules
      ..clear()
      ..addAll(nextRules);
  }

  bool removeRule(String ruleId) {
    final before = _rules.length;
    _rules.removeWhere((GameRule rule) => rule.id == ruleId);
    return before != _rules.length;
  }

  bool containsRule(String ruleId) =>
      _rules.any((GameRule rule) => rule.id == ruleId);

  RuleResolution resolve(GameEvent original, RuleContext context) {
    GameEvent? current = original;
    final followUps = <GameEvent>[];
    final appliedRuleIds = <String>[];

    for (final rule in _rules) {
      final event = current;
      if (event == null || !rule.applies(event, context)) {
        continue;
      }
      final result = rule.apply(event, context);
      current = result.primary;
      followUps.addAll(result.followUps);
      appliedRuleIds.add(rule.id);
    }

    return RuleResolution(
      primary: current,
      followUps: List<GameEvent>.unmodifiable(followUps),
      appliedRuleIds: List<String>.unmodifiable(appliedRuleIds),
    );
  }

  int _compareRules(GameRule a, GameRule b) {
    final priority = a.priority.compareTo(b.priority);
    return priority == 0 ? a.id.compareTo(b.id) : priority;
  }

  void _validateUniqueIdsAndPriorities(List<GameRule> rules) {
    final ids = <String>{};
    final priorities = <int>{};
    for (final rule in rules) {
      if (!ids.add(rule.id)) {
        throw StateError('Duplicate rule id: ${rule.id}');
      }
      if (!priorities.add(rule.priority)) {
        throw StateError(
          'Duplicate rule priority ${rule.priority}. Use explicit ordering.',
        );
      }
    }
  }
}
