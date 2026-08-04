import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

final class RetaliationEchoComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  RetaliationEchoComponent({required super.position})
    : super(
        radius: blastRadius,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x33FF4FD8),
        priority: 40,
      );

  static const double warningSeconds = 0.75;
  static const double blastSeconds = 0.12;
  static const double blastRadius = 60;

  final Set<Object> _hitTargets = <Object>{};
  double _warningRemaining = warningSeconds;
  double _blastRemaining = blastSeconds;
  bool _blastStarted = false;

  bool get blastStarted => _blastStarted;

  @override
  void update(double dt) {
    final simulationDt = isMounted ? game.clock.simulationDt : dt;
    if (!_blastStarted) {
      _warningRemaining -= simulationDt;
      final progress = (1 - (_warningRemaining / warningSeconds)).clamp(0, 1);
      scale.setAll(0.85 + (progress * 0.15));
      paint.color = Color.fromARGB(
        (55 + (progress * 110)).round(),
        255,
        79,
        216,
      );
      if (_warningRemaining <= 0) {
        unawaited(_startBlast());
      }
      super.update(dt);
      return;
    }
    _blastRemaining -= simulationDt;
    paint.color = const Color(0xAAFF4FD8);
    scale.setAll(1.12);
    if (_blastRemaining <= 0) {
      removeFromParent();
    }
    super.update(dt);
  }

  Future<void> _startBlast() async {
    if (_blastStarted) {
      return;
    }
    _blastStarted = true;
    await add(
      CircleHitbox.relative(
        1,
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (!_blastStarted || !_hitTargets.add(other)) {
      return;
    }
    if (other is PlayerComponent) {
      other.takeDamage(1, causeId: 'patch.retaliation_echo');
    }
    if (other is CombatTarget) {
      (other as CombatTarget).receiveDamage(1);
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
