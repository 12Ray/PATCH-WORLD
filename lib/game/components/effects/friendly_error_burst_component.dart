import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

final class FriendlyErrorBurstComponent extends CircleComponent
    with HasGameReference<PatchWorldGame> {
  FriendlyErrorBurstComponent({
    required super.position,
    required this.damage,
    required double blastRadius,
    this.excludedEntityId,
  }) : super(
         radius: blastRadius,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x5536E1FF),
         priority: 38,
       );

  final int damage;
  final String? excludedEntityId;
  double _remaining = 0.18;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final target in game.world.activeCombatTargets.toList()) {
      final combatTarget = target as CombatTarget;
      if (combatTarget.entityId == excludedEntityId) {
        continue;
      }
      if (target.position.distanceTo(position) <= radius) {
        combatTarget.receiveDamage(damage);
      }
    }
  }

  @override
  void update(double dt) {
    final simulationDt = game.clock.simulationDt;
    _remaining -= simulationDt;
    scale.setAll(1 + (0.18 - _remaining) * 1.8);
    paint.color = Color.fromRGBO(
      54,
      225,
      255,
      (_remaining / 0.18).clamp(0, 1) * 0.46,
    );
    if (_remaining <= 0) removeFromParent();
    super.update(dt);
  }
}
