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
}
