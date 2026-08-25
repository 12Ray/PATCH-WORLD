import 'dart:math' as math;
import 'dart:ui';

import 'package:patch_world/game/components/player/platformer_motion.dart';

/// One static, top-landable collision rectangle used by the campaign route
/// audit. Moving, breakable, phase-created, and ability-created platforms must
/// be omitted by the caller so they can never become a mandatory dependency.
final class OrdinaryJumpSurface {
  const OrdinaryJumpSurface({required this.id, required this.bounds});

  final String id;
  final Rect bounds;
}

/// A required campaign point expressed at the player's feet.
///
/// [settleDistance] permits a spawn to fall a short distance onto its authored
/// floor before movement begins. Door and terminal anchors should normally use
/// the default of zero because they are authored directly on a surface.
final class OrdinaryJumpAnchor {
  const OrdinaryJumpAnchor({
    required this.id,
    required this.feet,
    this.settleDistance = 0,
  });

  final String id;
  final Offset feet;
  final double settleDistance;
}

/// The unmodified movement values used by a sword player with no run items or
/// traversal unlocks. Defaults reference [PlatformerMotion] so level validation
/// cannot silently drift when the actual controller is tuned.
final class OrdinaryJumpMovementProfile {
  const OrdinaryJumpMovementProfile({
    this.runSpeed = PlatformerMotion.runSpeed,
    this.runAcceleration = PlatformerMotion.defaultRunAcceleration,
    this.runDeceleration = PlatformerMotion.defaultRunDeceleration,
    this.jumpSpeed = PlatformerMotion.defaultJumpSpeed,
    this.gravity = PlatformerMotion.defaultGravity,
    this.maximumFallSpeed = PlatformerMotion.defaultMaximumFallSpeed,
    this.jumpCutMultiplier = PlatformerMotion.defaultJumpCutMultiplier,
    this.playerWidth = PlatformerMotion.playerCollisionBodySize,
    this.playerHeight = PlatformerMotion.playerCollisionBodySize,
    this.minimumLandingWidth = PlatformerMotion.playerCollisionBodySize,
  });

  final double runSpeed;
  final double runAcceleration;
  final double runDeceleration;
  final double jumpSpeed;
  final double gravity;
  final double maximumFallSpeed;
  final double jumpCutMultiplier;
  final double playerWidth;
  final double playerHeight;
  final double minimumLandingWidth;

  double get maximumRise => jumpSpeed * jumpSpeed / (2 * gravity);

  /// Time until the descending jump arc reaches a landing [rise]. A positive
  /// rise means the destination is above the take-off surface.
  double? descendingFlightSeconds(double rise) {
    final discriminant = jumpSpeed * jumpSpeed - 2 * gravity * rise;
    if (discriminant < 0) return null;
    return (jumpSpeed + math.sqrt(discriminant)) / gravity;
  }

  double horizontalRangeAt(double rise) {
    final seconds = descendingFlightSeconds(rise);
    return seconds == null ? 0 : runSpeed * seconds;
  }
}

final class OrdinaryJumpTransition {
  const OrdinaryJumpTransition({
    required this.fromSurfaceId,
    required this.toSurfaceId,
    required this.rise,
    required this.gap,
    required this.maximumHorizontalRange,
  });

  final String fromSurfaceId;
  final String toSurfaceId;
  final double rise;
  final double gap;
  final double maximumHorizontalRange;
}

final class _OrdinaryVerticalTrajectory {
  const _OrdinaryVerticalTrajectory(this.feetDeltas);

  static const double stepSeconds = 1 / 120;

  final List<double> feetDeltas;

  double get flightSeconds => feetDeltas.length * stepSeconds;
}

/// Reachable surfaces and reconstructed routes from a single ordinary spawn.
final class OrdinaryJumpReachabilityResult {
  OrdinaryJumpReachabilityResult._({
    required Set<String> reachableSurfaceIds,
    required Map<String, Set<String>> anchorSurfaceIds,
    required Map<String, String?> predecessor,
  }) : reachableSurfaceIds = Set.unmodifiable(reachableSurfaceIds),
       _anchorSurfaceIds = Map.unmodifiable(anchorSurfaceIds),
       _predecessor = Map.unmodifiable(predecessor);

  final Set<String> reachableSurfaceIds;
  final Map<String, Set<String>> _anchorSurfaceIds;
  final Map<String, String?> _predecessor;

  bool isAnchorReachable(String anchorId) {
    final supports = _anchorSurfaceIds[anchorId];
    return supports != null && supports.any(reachableSurfaceIds.contains);
  }

  Set<String> supportingSurfaceIds(String anchorId) =>
      _anchorSurfaceIds[anchorId] ?? const <String>{};

  /// Returns the static surface route to [anchorId], or null when no ordinary
  /// movement route exists. The anchor itself is not appended to the path.
  List<String>? surfacePathTo(String anchorId) {
    final supports = _anchorSurfaceIds[anchorId];
    if (supports == null) return null;
    String? cursor;
    for (final candidate in supports) {
      if (reachableSurfaceIds.contains(candidate)) {
        cursor = candidate;
        break;
      }
    }
    if (cursor == null) return null;
    final reversed = <String>[];
    while (cursor != null) {
      reversed.add(cursor);
      cursor = _predecessor[cursor];
    }
    return reversed.reversed.toList(growable: false);
  }
}

/// Builds a directed graph from static surface geometry using the exact base
/// run speed, jump impulse, and gravity of [PlatformerMotion]. It intentionally
/// knows nothing about dash, double jump, wall jump, air dash, terrain pulse,
/// moving platforms, or combat knockback.
abstract final class OrdinaryJumpReachability {
  static const OrdinaryJumpMovementProfile swordBaseline =
      OrdinaryJumpMovementProfile();

  static OrdinaryJumpReachabilityResult analyze({
    required Iterable<OrdinaryJumpSurface> surfaces,
    required OrdinaryJumpAnchor start,
    required Iterable<OrdinaryJumpAnchor> requiredAnchors,
    OrdinaryJumpMovementProfile profile = swordBaseline,
  }) {
    final authored = List<OrdinaryJumpSurface>.unmodifiable(surfaces);
    final anchors = List<OrdinaryJumpAnchor>.unmodifiable(requiredAnchors);
    _validateInputs(authored, start, anchors, profile);
    final startSurfaces = supportingSurfaceIds(
      authored,
      start,
      profile: profile,
    );
    final anchorSurfaces = <String, Set<String>>{
      for (final anchor in anchors)
        anchor.id: supportingSurfaceIds(authored, anchor, profile: profile),
    };

    final adjacency = <String, List<String>>{};
    for (final from in authored) {
      for (final to in authored) {
        if (identical(from, to) || from.id == to.id) continue;
        if (transition(
              from,
              to,
              profile: profile,
              collisionSurfaces: authored,
            ) !=
            null) {
          adjacency.putIfAbsent(from.id, () => <String>[]).add(to.id);
        }
      }
    }

    final visited = <String>{...startSurfaces};
    final predecessor = <String, String?>{
      for (final id in startSurfaces) id: null,
    };
    final pending = <String>[...startSurfaces];
    while (pending.isNotEmpty) {
      final current = pending.removeAt(0);
      for (final next in adjacency[current] ?? const <String>[]) {
        if (!visited.add(next)) continue;
        predecessor[next] = current;
        pending.add(next);
      }
    }

    return OrdinaryJumpReachabilityResult._(
      reachableSurfaceIds: visited,
      anchorSurfaceIds: anchorSurfaces,
      predecessor: predecessor,
    );
  }

  static OrdinaryJumpTransition? transition(
    OrdinaryJumpSurface from,
    OrdinaryJumpSurface to, {
    OrdinaryJumpMovementProfile profile = swordBaseline,
    Iterable<OrdinaryJumpSurface> collisionSurfaces =
        const <OrdinaryJumpSurface>[],
  }) {
    if (from.bounds.isEmpty || to.bounds.isEmpty) return null;
    if (to.bounds.width < profile.minimumLandingWidth) return null;
    final authoredCollisionSurfaces = List<OrdinaryJumpSurface>.unmodifiable(
      collisionSurfaces,
    );
    if (_standableSpanIsSplit(
      from,
      authoredCollisionSurfaces,
      profile: profile,
    )) {
      return null;
    }
    final rise = from.bounds.top - to.bounds.top;
    final maximumRange = profile.horizontalRangeAt(rise);
    if (maximumRange <= 0) return null;
    final gap = _horizontalGap(from.bounds, to.bounds);
    if (gap > maximumRange + .001) return null;
    if (!_hasClearTrajectory(
      from,
      to,
      authoredCollisionSurfaces,
      profile: profile,
      rise: rise,
    )) {
      return null;
    }
    return OrdinaryJumpTransition(
      fromSurfaceId: from.id,
      toSurfaceId: to.id,
      rise: rise,
      gap: gap,
      maximumHorizontalRange: maximumRange,
    );
  }

  /// Resolves the nearest static floor at or below an anchor's feet.
  static Set<String> supportingSurfaceIds(
    Iterable<OrdinaryJumpSurface> surfaces,
    OrdinaryJumpAnchor anchor, {
    OrdinaryJumpMovementProfile profile = swordBaseline,
  }) {
    var nearestDrop = double.infinity;
    final supports = <String>{};
    final halfWidth = profile.playerWidth / 2;
    for (final surface in surfaces) {
      if (surface.bounds.isEmpty) continue;
      final horizontallySupported =
          anchor.feet.dx >= surface.bounds.left - halfWidth &&
          anchor.feet.dx <= surface.bounds.right + halfWidth;
      if (!horizontallySupported) continue;
      final drop = surface.bounds.top - anchor.feet.dy;
      if (drop < -.001 || drop > anchor.settleDistance + .001) continue;
      if (drop < nearestDrop - .001) {
        nearestDrop = drop;
        supports
          ..clear()
          ..add(surface.id);
      } else if ((drop - nearestDrop).abs() <= .001) {
        supports.add(surface.id);
      }
    }
    return Set.unmodifiable(supports);
  }

  static double _horizontalGap(Rect from, Rect to) {
    if (from.right < to.left) return to.left - from.right;
    if (to.right < from.left) return from.left - to.right;
    return 0;
  }

  static bool _hasClearTrajectory(
    OrdinaryJumpSurface from,
    OrdinaryJumpSurface to,
    Iterable<OrdinaryJumpSurface> collisionSurfaces, {
    required OrdinaryJumpMovementProfile profile,
    required double rise,
  }) {
    final halfWidth = profile.playerWidth / 2;
    final corridor = Rect.fromLTRB(
      math.min(from.bounds.left, to.bounds.left) - halfWidth,
      math.min(from.bounds.top, to.bounds.top) -
          profile.maximumRise -
          profile.playerHeight,
      math.max(from.bounds.right, to.bounds.right) + halfWidth,
      math.max(from.bounds.top, to.bounds.top) + profile.playerHeight,
    );
    final blockerById = <String, OrdinaryJumpSurface>{to.id: to};
    for (final surface in collisionSurfaces) {
      if (surface.bounds.overlaps(corridor)) {
        blockerById[surface.id] = surface;
      }
    }
    final blockers = blockerById.values.toList(growable: false);

    final direction = to.bounds.center.dx >= from.bounds.center.dx ? 1.0 : -1.0;
    if (rise < 0 &&
        _hasClearWalkOff(
          from,
          to,
          direction: direction,
          blockers: blockers,
          profile: profile,
          dropDistance: -rise,
        )) {
      return true;
    }
    final trajectories = _ordinaryVerticalTrajectories(profile, rise);
    const launchSamples = 8;
    const initialSpeedFractions = <double>[0, .5, 1];
    const controlWindows = <(double, double)>[
      (0, 0),
      (0, .25),
      (0, .5),
      (0, .75),
      (0, 1),
      (.25, 1),
      (.5, 1),
      (.75, 1),
    ];
    for (final trajectory in trajectories) {
      for (
        var launchIndex = 0;
        launchIndex <= launchSamples;
        launchIndex += 1
      ) {
        final launchX =
            from.bounds.left +
            from.bounds.width * (launchIndex / launchSamples);
        final runUpDistance = direction > 0
            ? launchX - from.bounds.left
            : from.bounds.right - launchX;
        final attainableInitialSpeed = math.min(
          profile.runSpeed,
          math.sqrt(2 * profile.runAcceleration * runUpDistance),
        );
        for (final initialSpeedFraction in initialSpeedFractions) {
          for (final controlWindow in controlWindows) {
            final horizontalDeltas = _horizontalDeltas(
              sampleCount: trajectory.feetDeltas.length,
              direction: direction,
              initialSpeed:
                  attainableInitialSpeed * initialSpeedFraction * direction,
              controlStartFraction: controlWindow.$1,
              controlEndFraction: controlWindow.$2,
              profile: profile,
            );
            final landingX = launchX + horizontalDeltas.last;
            if (landingX < to.bounds.left - .001 ||
                landingX > to.bounds.right + .001) {
              continue;
            }
            if (_trajectoryAvoidsBlockers(
              launchX: launchX,
              takeoffY: from.bounds.top,
              horizontalDeltas: horizontalDeltas,
              trajectory: trajectory,
              blockers: blockers,
              takeoffSurfaceId: from.id,
              landingSurfaceId: to.id,
              sameLevelLanding: rise.abs() <= .001,
              profile: profile,
            )) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  static bool _hasClearWalkOff(
    OrdinaryJumpSurface from,
    OrdinaryJumpSurface to, {
    required double direction,
    required List<OrdinaryJumpSurface> blockers,
    required OrdinaryJumpMovementProfile profile,
    required double dropDistance,
  }) {
    final trajectory = _ordinaryDropTrajectory(profile, dropDistance);
    if (trajectory == null) return false;
    final halfWidth = profile.playerWidth / 2;
    final launchX = direction > 0
        ? from.bounds.right + halfWidth
        : from.bounds.left - halfWidth;
    final attainableInitialSpeed = math.min(
      profile.runSpeed,
      math.sqrt(2 * profile.runAcceleration * from.bounds.width),
    );
    const initialSpeedFractions = <double>[.5, .75, 1];
    const controlWindows = <(double, double)>[(0, 0), (0, .5), (0, 1), (.5, 1)];
    for (final initialSpeedFraction in initialSpeedFractions) {
      for (final controlWindow in controlWindows) {
        final horizontalDeltas = _horizontalDeltas(
          sampleCount: trajectory.feetDeltas.length,
          direction: direction,
          initialSpeed:
              attainableInitialSpeed * initialSpeedFraction * direction,
          controlStartFraction: controlWindow.$1,
          controlEndFraction: controlWindow.$2,
          profile: profile,
        );
        final landingX = launchX + horizontalDeltas.last;
        if (landingX < to.bounds.left - .001 ||
            landingX > to.bounds.right + .001) {
          continue;
        }
        if (_trajectoryAvoidsBlockers(
          launchX: launchX,
          takeoffY: from.bounds.top,
          horizontalDeltas: horizontalDeltas,
          trajectory: trajectory,
          blockers: blockers,
          takeoffSurfaceId: from.id,
          landingSurfaceId: to.id,
          sameLevelLanding: false,
          profile: profile,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Samples the same 120 Hz integration and one-shot jump cut used by
  /// PlayerComponent. Holding for the full arc and short taps are both valid
  /// ordinary jumps; no second impulse or traversal ability is introduced.
  static List<_OrdinaryVerticalTrajectory> _ordinaryVerticalTrajectories(
    OrdinaryJumpMovementProfile profile,
    double rise,
  ) {
    const stepSeconds = 1 / 120;
    const releaseFrames = <int?>[18, 21, 24, 27, 30, 33, 36, 42, null];
    final targetDelta = -rise;
    final trajectories = <_OrdinaryVerticalTrajectory>[];
    for (final releaseFrame in releaseFrames) {
      var velocity = -profile.jumpSpeed;
      var feetDelta = 0.0;
      var cutApplied = false;
      var reachedTargetHeight = targetDelta >= 0;
      final samples = <double>[];
      for (var frame = 1; frame <= 360; frame += 1) {
        if (!cutApplied &&
            releaseFrame != null &&
            frame >= releaseFrame &&
            velocity < 0) {
          velocity *= profile.jumpCutMultiplier;
          cutApplied = true;
        }
        velocity = math.min(
          profile.maximumFallSpeed,
          velocity + profile.gravity * stepSeconds,
        );
        feetDelta += velocity * stepSeconds;
        samples.add(feetDelta);
        if (feetDelta <= targetDelta + .001) reachedTargetHeight = true;
        if (velocity >= 0 && reachedTargetHeight && feetDelta >= targetDelta) {
          trajectories.add(
            _OrdinaryVerticalTrajectory(List<double>.unmodifiable(samples)),
          );
          break;
        }
        if (velocity >= 0 && !reachedTargetHeight) break;
      }
    }
    return trajectories;
  }

  static _OrdinaryVerticalTrajectory? _ordinaryDropTrajectory(
    OrdinaryJumpMovementProfile profile,
    double dropDistance,
  ) {
    if (dropDistance <= 0) return null;
    var velocity = 0.0;
    var feetDelta = 0.0;
    final samples = <double>[];
    for (var frame = 1; frame <= 360; frame += 1) {
      velocity = math.min(
        profile.maximumFallSpeed,
        velocity + profile.gravity * _OrdinaryVerticalTrajectory.stepSeconds,
      );
      feetDelta += velocity * _OrdinaryVerticalTrajectory.stepSeconds;
      samples.add(feetDelta);
      if (feetDelta >= dropDistance) {
        return _OrdinaryVerticalTrajectory(List<double>.unmodifiable(samples));
      }
    }
    return null;
  }

  static bool _trajectoryAvoidsBlockers({
    required double launchX,
    required double takeoffY,
    required List<double> horizontalDeltas,
    required _OrdinaryVerticalTrajectory trajectory,
    required List<OrdinaryJumpSurface> blockers,
    required String takeoffSurfaceId,
    required String landingSurfaceId,
    required bool sameLevelLanding,
    required OrdinaryJumpMovementProfile profile,
  }) {
    final halfWidth = profile.playerWidth / 2;
    final finalIndex = trajectory.feetDeltas.length - 1;
    for (var index = 0; index <= finalIndex; index += 1) {
      final centerX = launchX + horizontalDeltas[index];
      final feetY = takeoffY + trajectory.feetDeltas[index];
      final playerBounds = Rect.fromLTRB(
        centerX - halfWidth,
        feetY - profile.playerHeight,
        centerX + halfWidth,
        feetY,
      );
      final blocked = blockers.any((surface) {
        if (index == finalIndex && surface.id == landingSurfaceId) return false;
        if (index == finalIndex &&
            sameLevelLanding &&
            surface.id == takeoffSurfaceId) {
          return false;
        }
        return playerBounds.overlaps(surface.bounds);
      });
      if (blocked) {
        return false;
      }
    }
    return true;
  }

  static List<double> _horizontalDeltas({
    required int sampleCount,
    required double direction,
    required double initialSpeed,
    required double controlStartFraction,
    required double controlEndFraction,
    required OrdinaryJumpMovementProfile profile,
  }) {
    var velocity = initialSpeed;
    var delta = 0.0;
    final samples = <double>[];
    for (var index = 0; index < sampleCount; index += 1) {
      final fraction = sampleCount <= 1 ? 1.0 : index / (sampleCount - 1);
      final holdingDirection =
          fraction >= controlStartFraction && fraction < controlEndFraction;
      final target = holdingDirection ? direction * profile.runSpeed : 0.0;
      final acceleration = holdingDirection
          ? profile.runAcceleration
          : profile.runDeceleration;
      velocity = _moveTowards(
        velocity,
        target,
        acceleration * _OrdinaryVerticalTrajectory.stepSeconds,
      );
      delta += velocity * _OrdinaryVerticalTrajectory.stepSeconds;
      samples.add(delta);
    }
    return samples;
  }

  static double _moveTowards(double current, double target, double delta) {
    if ((target - current).abs() <= delta) return target;
    return current + (target > current ? delta : -delta);
  }

  static bool _standableSpanIsSplit(
    OrdinaryJumpSurface surface,
    Iterable<OrdinaryJumpSurface> collisionSurfaces, {
    required OrdinaryJumpMovementProfile profile,
  }) {
    final halfWidth = profile.playerWidth / 2;
    final standingTop = surface.bounds.top - profile.playerHeight;
    for (final blocker in collisionSurfaces) {
      if (blocker.id == surface.id) continue;
      final occupiesStandingBand =
          blocker.bounds.top < surface.bounds.top - .001 &&
          blocker.bounds.bottom > standingTop + .001;
      if (!occupiesStandingBand) continue;
      final blockedLeft = blocker.bounds.left - halfWidth;
      final blockedRight = blocker.bounds.right + halfWidth;
      final leavesWalkableLeft =
          blockedLeft - surface.bounds.left >= profile.minimumLandingWidth;
      final leavesWalkableRight =
          surface.bounds.right - blockedRight >= profile.minimumLandingWidth;
      if (leavesWalkableLeft && leavesWalkableRight) return true;
    }
    return false;
  }

  static void _validateInputs(
    List<OrdinaryJumpSurface> surfaces,
    OrdinaryJumpAnchor start,
    Iterable<OrdinaryJumpAnchor> requiredAnchors,
    OrdinaryJumpMovementProfile profile,
  ) {
    if (profile.runSpeed <= 0 ||
        profile.runAcceleration <= 0 ||
        profile.runDeceleration <= 0 ||
        profile.jumpSpeed <= 0 ||
        profile.gravity <= 0 ||
        profile.maximumFallSpeed <= 0 ||
        profile.jumpCutMultiplier <= 0 ||
        profile.jumpCutMultiplier > 1 ||
        profile.playerWidth <= 0 ||
        profile.playerHeight <= 0 ||
        profile.minimumLandingWidth <= 0) {
      throw ArgumentError('Ordinary-jump movement values must be positive.');
    }
    final surfaceIds = <String>{};
    for (final surface in surfaces) {
      if (surface.id.isEmpty || !surfaceIds.add(surface.id)) {
        throw ArgumentError('Static surface ids must be non-empty and unique.');
      }
      if (surface.bounds.isEmpty) {
        throw ArgumentError('Static surface ${surface.id} is empty.');
      }
    }
    for (final surface in surfaces) {
      if (_standableSpanIsSplit(surface, surfaces, profile: profile)) {
        throw ArgumentError(
          'Static surface ${surface.id} is split by a standing-height solid; '
          'author each walkable side as a separate surface.',
        );
      }
    }
    final anchorIds = <String>{start.id};
    if (start.id.isEmpty || start.settleDistance < 0) {
      throw ArgumentError('The start anchor is invalid.');
    }
    for (final anchor in requiredAnchors) {
      if (anchor.id.isEmpty || !anchorIds.add(anchor.id)) {
        throw ArgumentError('Anchor ids must be non-empty and unique.');
      }
      if (anchor.settleDistance < 0) {
        throw ArgumentError('Anchor settle distance cannot be negative.');
      }
    }
  }
}
