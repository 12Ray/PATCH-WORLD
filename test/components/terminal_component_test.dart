import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/terminal_component.dart';

void main() {
  test('terminal activates once when player is within range', () {
    var callbacks = 0;
    final terminal = TerminalComponent(
      terminalId: 'terminal-a',
      position: Vector2(100, 100),
      onActivated: (_) => callbacks += 1,
    );
    expect(terminal.tryActivate(Vector2(200, 100)), isFalse);
    expect(terminal.tryActivate(Vector2(130, 100)), isTrue);
    expect(terminal.tryActivate(Vector2(130, 100)), isFalse);
    expect(callbacks, 1);
  });

  test('charged terminal requires movement time before activation', () {
    var activationCount = 0;
    final terminal = TerminalComponent(
      terminalId: 'temporal-relay',
      position: Vector2.zero(),
      requiredChargeSeconds: 0.8,
      onActivated: (_) => activationCount += 1,
    );

    terminal.updateCharge(
      playerPosition: Vector2.zero(),
      dt: 0.4,
      isMoving: false,
    );
    expect(terminal.chargeProgress, 0);
    expect(terminal.tryActivate(Vector2.zero()), isFalse);

    terminal.updateCharge(
      playerPosition: Vector2.zero(),
      dt: 0.8,
      isMoving: true,
    );
    expect(terminal.isReady, isTrue);
    expect(terminal.tryActivate(Vector2.zero()), isTrue);
    expect(activationCount, 1);
  });
}
