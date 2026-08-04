import 'dart:math' as math;

import 'package:flame/components.dart';

final class SurvivalCrowdNeighbor {
  const SurvivalCrowdNeighbor({required this.entityId, required this.position});

  final String entityId;
  final Vector2 position;
}

abstract final class SurvivalCrowdSeparation {
  static Vector2 steering({
    required String entityId,
    required Vector2 position,
    required Iterable<SurvivalCrowdNeighbor> neighbors,
    required double separationRadius,
  }) {
    if (separationRadius <= 0) return Vector2.zero();
    final steering = Vector2.zero();
    for (final neighbor in neighbors) {
      if (neighbor.entityId == entityId) continue;
      final away = position - neighbor.position;
      final distanceSquared = away.length2;
      if (distanceSquared >= separationRadius * separationRadius) continue;
      final distance = math.sqrt(distanceSquared);
      final direction = distance <= 0.001
          ? _overlapDirection(entityId, neighbor.entityId)
          : away / distance;
      final weight = 1 - distance / separationRadius;
      steering.add(direction * weight);
    }
    if (steering.length2 > 1) steering.normalize();
    return steering;
  }

  static Vector2 _overlapDirection(String entityId, String neighborId) {
    final entityFirst = entityId.compareTo(neighborId) < 0;
    final first = entityFirst ? entityId : neighborId;
    final second = entityFirst ? neighborId : entityId;
    final angle = (_stableHash('$first|$second') % 360) * math.pi / 180;
    final direction = Vector2(math.cos(angle), math.sin(angle));
    return entityFirst ? direction : -direction;
  }

  static int _stableHash(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}
