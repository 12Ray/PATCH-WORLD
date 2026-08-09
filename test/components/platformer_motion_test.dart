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
  });
}
