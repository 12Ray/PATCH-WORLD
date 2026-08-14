import 'package:patch_world/game/combat/player_weapon.dart';

/// Safety budget for every route that is required to finish the campaign.
///
/// These values intentionally leave margin below the theoretical jump arc.
/// Weapon movement powers may exceed the budget only on optional routes.
abstract final class PlatformerTraversalContract {
  static const double maximumRequiredRise = 80;
  static const double maximumRequiredGap = 120;
  static const double minimumRequiredLandingWidth = 96;

  static List<TraversalViolation> validateRequiredRoute(
    Iterable<TraversalSegment> segments, {
    required PlayerWeapon weapon,
  }) {
    final violations = <TraversalViolation>[];
    for (final segment in segments) {
      if (!segment.requiredForCompletion) continue;
      if (segment.rise > maximumRequiredRise) {
        violations.add(
          TraversalViolation(
            segment.id,
            'rise ${segment.rise} exceeds $maximumRequiredRise',
          ),
        );
      }
      if (segment.gap > maximumRequiredGap) {
        violations.add(
          TraversalViolation(
            segment.id,
            'gap ${segment.gap} exceeds $maximumRequiredGap',
          ),
        );
      }
      if (segment.landingWidth < minimumRequiredLandingWidth) {
        violations.add(
          TraversalViolation(
            segment.id,
            'landing ${segment.landingWidth} is below '
            '$minimumRequiredLandingWidth',
          ),
        );
      }
      if (segment.requiresMovingPlatform || segment.requiresBreakablePlatform) {
        violations.add(
          TraversalViolation(
            segment.id,
            'required route depends on a non-static platform',
          ),
        );
      }
      if (segment.requirement != TraversalAbilityRequirement.universal) {
        violations.add(
          TraversalViolation(
            segment.id,
            'required route is gated by ${segment.requirement.name} for '
            '${weapon.name}',
          ),
        );
      }
    }
    return violations;
  }
}

enum TraversalAbilityRequirement {
  universal,
  swordDash,
  gauntletDoubleJump,
  gunRangedSwitch,
}

final class TraversalSegment {
  const TraversalSegment({
    required this.id,
    required this.rise,
    required this.gap,
    required this.landingWidth,
    this.requiredForCompletion = true,
    this.requirement = TraversalAbilityRequirement.universal,
    this.requiresMovingPlatform = false,
    this.requiresBreakablePlatform = false,
  });

  final String id;
  final double rise;
  final double gap;
  final double landingWidth;
  final bool requiredForCompletion;
  final TraversalAbilityRequirement requirement;
  final bool requiresMovingPlatform;
  final bool requiresBreakablePlatform;
}

final class TraversalViolation {
  const TraversalViolation(this.segmentId, this.reason);

  final String segmentId;
  final String reason;

  @override
  String toString() => '$segmentId: $reason';
}
