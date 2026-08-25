import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/ordinary_jump_reachability.dart';
import 'package:patch_world/game/components/player/platformer_motion.dart';

void main() {
  test(
    'baseline envelope is derived from the live player motion constants',
    () {
      const profile = OrdinaryJumpReachability.swordBaseline;

      expect(profile.runSpeed, PlatformerMotion.runSpeed);
      expect(profile.runAcceleration, PlatformerMotion.defaultRunAcceleration);
      expect(profile.runDeceleration, PlatformerMotion.defaultRunDeceleration);
      expect(profile.jumpSpeed, PlatformerMotion.defaultJumpSpeed);
      expect(profile.gravity, PlatformerMotion.defaultGravity);
      expect(profile.playerWidth, PlatformerMotion.playerCollisionBodySize);
      expect(profile.playerHeight, PlatformerMotion.playerCollisionBodySize);
      expect(profile.maximumRise, closeTo(100.409, .001));
      expect(profile.horizontalRangeAt(0), closeTo(162.363, .001));
    },
  );

  test('ordinary single jumps connect a conservative two-step staircase', () {
    const surfaces = <OrdinaryJumpSurface>[
      OrdinaryJumpSurface(id: 'floor', bounds: Rect.fromLTWH(0, 200, 180, 40)),
      OrdinaryJumpSurface(id: 'step', bounds: Rect.fromLTWH(160, 125, 120, 24)),
      OrdinaryJumpSurface(id: 'exit', bounds: Rect.fromLTWH(260, 50, 140, 24)),
    ];
    const exit = OrdinaryJumpAnchor(id: 'exitDoor', feet: Offset(340, 50));

    final result = OrdinaryJumpReachability.analyze(
      surfaces: surfaces,
      start: const OrdinaryJumpAnchor(
        id: 'spawn',
        feet: Offset(80, 180),
        settleDistance: 24,
      ),
      requiredAnchors: const <OrdinaryJumpAnchor>[exit],
    );

    expect(result.isAnchorReachable(exit.id), isTrue);
    expect(result.surfacePathTo(exit.id), <String>['floor', 'step', 'exit']);
  });

  test('a rise above the real apex cannot masquerade as an ordinary jump', () {
    const floor = OrdinaryJumpSurface(
      id: 'floor',
      bounds: Rect.fromLTWH(0, 220, 140, 40),
    );
    const tooHigh = OrdinaryJumpSurface(
      id: 'tooHigh',
      bounds: Rect.fromLTWH(120, 110, 140, 24),
    );

    expect(OrdinaryJumpReachability.transition(floor, tooHigh), isNull);
  });

  test('same-level range and landing width reject unsafe pasted geometry', () {
    const floor = OrdinaryJumpSurface(
      id: 'floor',
      bounds: Rect.fromLTWH(0, 200, 100, 40),
    );
    const reachable = OrdinaryJumpSurface(
      id: 'reachable',
      bounds: Rect.fromLTWH(250, 200, 96, 24),
    );
    const tooFar = OrdinaryJumpSurface(
      id: 'tooFar',
      bounds: Rect.fromLTWH(270, 200, 96, 24),
    );
    const tooNarrow = OrdinaryJumpSurface(
      id: 'tooNarrow',
      bounds: Rect.fromLTWH(110, 200, 24, 24),
    );

    expect(OrdinaryJumpReachability.transition(floor, reachable), isNotNull);
    expect(OrdinaryJumpReachability.transition(floor, tooFar), isNull);
    expect(OrdinaryJumpReachability.transition(floor, tooNarrow), isNull);
  });

  test('collision corridor rejects a 204px wall but clears an 80px wall', () {
    const left = OrdinaryJumpSurface(
      id: 'left',
      bounds: Rect.fromLTWH(0, 400, 560, 40),
    );
    const right = OrdinaryJumpSurface(
      id: 'right',
      bounds: Rect.fromLTWH(584, 400, 300, 40),
    );
    const tallWall = OrdinaryJumpSurface(
      id: 'tallWall',
      bounds: Rect.fromLTWH(560, 196, 24, 204),
    );
    const ordinaryWall = OrdinaryJumpSurface(
      id: 'ordinaryWall',
      bounds: Rect.fromLTWH(560, 320, 24, 80),
    );

    expect(
      OrdinaryJumpReachability.transition(
        left,
        right,
        collisionSurfaces: const <OrdinaryJumpSurface>[left, right, tallWall],
      ),
      isNull,
    );
    expect(
      OrdinaryJumpReachability.transition(
        left,
        right,
        collisionSurfaces: const <OrdinaryJumpSurface>[
          left,
          right,
          ordinaryWall,
        ],
      ),
      isNotNull,
    );
  });

  test('a short ordinary jump-cut clears a 75px step under a ceiling', () {
    const floor = OrdinaryJumpSurface(
      id: 'floor',
      bounds: Rect.fromLTWH(0, 200, 140, 40),
    );
    const step = OrdinaryJumpSurface(
      id: 'step',
      bounds: Rect.fromLTWH(120, 125, 160, 24),
    );
    const lowCeiling = OrdinaryJumpSurface(
      id: 'lowCeiling',
      bounds: Rect.fromLTWH(0, 45, 280, 24),
    );

    expect(
      OrdinaryJumpReachability.transition(
        floor,
        step,
        collisionSurfaces: const <OrdinaryJumpSurface>[floor, step, lowCeiling],
      ),
      isNotNull,
      reason:
          'Releasing jump during ascent must be modeled as an ordinary input.',
    );
  });

  test('a destination ceiling cannot be crossed from its underside', () {
    const floor = OrdinaryJumpSurface(
      id: 'floor',
      bounds: Rect.fromLTWH(0, 200, 200, 40),
    );
    const ceilingLikeTarget = OrdinaryJumpSurface(
      id: 'ceilingTarget',
      bounds: Rect.fromLTWH(0, 125, 200, 24),
    );

    expect(
      OrdinaryJumpReachability.transition(
        floor,
        ceilingLikeTarget,
        collisionSurfaces: const <OrdinaryJumpSurface>[
          floor,
          ceilingLikeTarget,
        ],
      ),
      isNull,
      reason: 'The target stays solid until the final descending landing.',
    );
  });

  test('horizontal range obeys acceleration instead of instant run speed', () {
    const slowProfile = OrdinaryJumpMovementProfile(
      runAcceleration: 10,
      runDeceleration: 10,
    );
    const floor = OrdinaryJumpSurface(
      id: 'floor',
      bounds: Rect.fromLTWH(0, 200, 32, 40),
    );
    const distant = OrdinaryJumpSurface(
      id: 'distant',
      bounds: Rect.fromLTWH(132, 200, 96, 24),
    );

    expect(slowProfile.horizontalRangeAt(0), greaterThan(100));
    expect(
      OrdinaryJumpReachability.transition(
        floor,
        distant,
        profile: slowProfile,
        collisionSurfaces: const <OrdinaryJumpSurface>[floor, distant],
      ),
      isNull,
    );
  });

  test('a lower platform cannot be reached by falling through the source', () {
    const upperFloor = OrdinaryJumpSurface(
      id: 'upperFloor',
      bounds: Rect.fromLTWH(0, 100, 300, 24),
    );
    const containedLowerFloor = OrdinaryJumpSurface(
      id: 'containedLowerFloor',
      bounds: Rect.fromLTWH(100, 200, 100, 24),
    );

    expect(
      OrdinaryJumpReachability.transition(
        upperFloor,
        containedLowerFloor,
        collisionSurfaces: const <OrdinaryJumpSurface>[
          upperFloor,
          containedLowerFloor,
        ],
      ),
      isNull,
      reason: 'The solid take-off floor must catch the descending player.',
    );
  });

  test('a wall-divided source must be authored as separate surfaces', () {
    const floor = OrdinaryJumpSurface(
      id: 'wideFloor',
      bounds: Rect.fromLTWH(0, 200, 420, 40),
    );
    const divider = OrdinaryJumpSurface(
      id: 'divider',
      bounds: Rect.fromLTWH(196, 80, 28, 120),
    );

    expect(
      () => OrdinaryJumpReachability.analyze(
        surfaces: const <OrdinaryJumpSurface>[floor, divider],
        start: const OrdinaryJumpAnchor(id: 'spawn', feet: Offset(80, 200)),
        requiredAnchors: const <OrdinaryJumpAnchor>[
          OrdinaryJumpAnchor(id: 'farDoor', feet: Offset(340, 200)),
        ],
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('author each walkable side as a separate surface'),
        ),
      ),
    );
  });

  test('the final landing frame still collides with third-party solids', () {
    const upper = OrdinaryJumpSurface(
      id: 'upper',
      bounds: Rect.fromLTWH(0, 100, 100, 24),
    );
    const lower = OrdinaryJumpSurface(
      id: 'lower',
      bounds: Rect.fromLTWH(150, 200, 100, 24),
    );
    const landingSliver = OrdinaryJumpSurface(
      id: 'landingSliver',
      bounds: Rect.fromLTWH(150, 199, 100, 1),
    );

    expect(
      OrdinaryJumpReachability.transition(
        upper,
        lower,
        collisionSurfaces: const <OrdinaryJumpSurface>[
          upper,
          lower,
          landingSliver,
        ],
      ),
      isNull,
    );
  });
}
