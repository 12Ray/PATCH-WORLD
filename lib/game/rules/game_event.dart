enum EventFaction { player, enemy, environment }

sealed class GameEvent {
  const GameEvent({required this.sourceId, required this.targetId});

  final String sourceId;
  final String targetId;
}

final class DamageEvent extends GameEvent {
  const DamageEvent({
    required super.sourceId,
    required super.targetId,
    required this.sourceFaction,
    required this.amount,
  });

  final EventFaction sourceFaction;
  final int amount;
}

final class HealEvent extends GameEvent {
  const HealEvent({
    required super.sourceId,
    required super.targetId,
    required this.sourceFaction,
    required this.amount,
  });

  final EventFaction sourceFaction;
  final int amount;
}
