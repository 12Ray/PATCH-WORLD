import 'dart:ui';

import 'package:flame/components.dart';

enum AttackTier { normal, enhanced, parryable }

extension AttackTierSpec on AttackTier {
  bool get canBeParried => this == AttackTier.parryable;

  Color get color => switch (this) {
    AttackTier.normal => const Color(0xFF36E1FF),
    AttackTier.enhanced => const Color(0xFFFF4FD8),
    AttackTier.parryable => const Color(0xFFFFD35A),
  };

  Color get trailColor => switch (this) {
    AttackTier.normal => const Color(0x8836E1FF),
    AttackTier.enhanced => const Color(0xAAFF4FD8),
    AttackTier.parryable => const Color(0xAAFFF4B0),
  };
}

abstract interface class ReflectableAttack {
  AttackTier get attackTier;
  bool get isReflected;
  bool reflectFrom(Vector2 sourcePosition);
}
