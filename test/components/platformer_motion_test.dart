import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/player/platformer_motion.dart';

void main() {
  group('PlatformerMotion', () {
    test('accelerates toward run speed and decelerates without input', () {
      final motion = PlatformerMotion();

      motion.advance(0.1, horizontal: 1, jumpHeld: false);
      expect(motion.velocity.x, 120);

      motion.advance(0.1, horizontal: 0, jumpHeld: false);
      expect(motion.velocity.x, 0);
    });

    test('jumps during coyote window after leaving a platform', () {
      final motion = PlatformerMotion()..grounded = true;

      motion.advance(0.016, horizontal: 0, jumpHeld: true);
      motion.beginVerticalResolution();
      motion.advance(0.05, horizontal: 0, jumpHeld: true);
      motion.queueJump();
      motion.advance(0.01, horizontal: 0, jumpHeld: true);

      expect(motion.velocity.y, lessThan(0));
      expect(motion.grounded, isFalse);
    });

    test('buffered jump fires on the first grounded frame', () {
      final motion = PlatformerMotion();

      motion.queueJump();
      motion.advance(0.05, horizontal: 0, jumpHeld: true);
      motion.land();
      motion.advance(0.01, horizontal: 0, jumpHeld: true);

      expect(motion.velocity.y, lessThan(-350));
      expect(motion.grounded, isFalse);
    });

    test('releasing jump early produces a shorter ascent', () {
      final held = PlatformerMotion()..grounded = true;
      final released = PlatformerMotion()..grounded = true;
      held.queueJump();
      released.queueJump();

      held.advance(0.016, horizontal: 0, jumpHeld: true);
      released.advance(0.016, horizontal: 0, jumpHeld: false);

      expect(released.velocity.y, greaterThan(held.velocity.y));
    });

    test('full jump clears a ninety pixel mandatory platform step', () {
      final motion = PlatformerMotion()..grounded = true;
      motion.queueJump();
      var height = 0.0;
      var peak = 0.0;

      for (var frame = 0; frame < 120; frame += 1) {
        motion.advance(1 / 120, horizontal: 0, jumpHeld: true);
        height -= motion.velocity.y / 120;
        peak = peak < height ? height : peak;
        motion.beginVerticalResolution();
        if (motion.velocity.y >= 0) break;
      }

      expect(peak, greaterThan(90));
    });

    test('gauntlet air jump uses eighty-two percent jump force', () {
      final motion = PlatformerMotion();

      expect(motion.tryAirJump(), isTrue);
      expect(motion.velocity.y, closeTo(-motion.jumpSpeed * 0.82, 0.001));
      expect(motion.grounded, isFalse);
    });

    test('run speed multiplier supports gauntlet movement penalty', () {
      final normal = PlatformerMotion();
      final gauntlet = PlatformerMotion();

      normal.advance(1, horizontal: 1, jumpHeld: false);
      gauntlet.advance(
        1,
        horizontal: 1,
        jumpHeld: false,
        runSpeedMultiplier: 0.95,
      );

      expect(normal.velocity.x, normal.maxRunSpeed);
      expect(gauntlet.velocity.x, gauntlet.maxRunSpeed * 0.95);
    });
  });
}
