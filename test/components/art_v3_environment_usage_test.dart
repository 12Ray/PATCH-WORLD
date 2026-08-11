import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/legacy_glitch_terminal.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';

void main() {
  test('every Art v3 environment role has a runtime owner', () {
    final surface = PlatformSurfaceComponent(
      position: Vector2.zero(),
      size: Vector2(160, 28),
    );
    final wall = PlatformSurfaceComponent(
      position: Vector2.zero(),
      size: Vector2(28, 160),
    );
    final statePlatform = MovingPlatformComponent(
      start: Vector2.zero(),
      end: Vector2(100, 0),
      size: Vector2(120, 20),
      periodSeconds: 2,
    );
    final gate = BossSealGateComponent(
      position: Vector2.zero(),
      size: Vector2(28, 180),
      style: PlatformSurfaceStyle.damage,
    );
    final terminal = LegacyGlitchTerminal(
      position: Vector2.zero(),
      onActivated: () {},
    );

    expect(surface.foregroundRole, ArtV3EnvironmentRole.surface);
    expect(wall.foregroundRole, ArtV3EnvironmentRole.cornerWall);
    expect(statePlatform.foregroundRole, ArtV3EnvironmentRole.statePlatform);
    expect(gate.foregroundRole, ArtV3EnvironmentRole.interactive);
    expect(terminal.foregroundRole, ArtV3EnvironmentRole.interactive);
    expect(
      ArtV3EnvironmentRole.values.map(artV3EnvironmentSourceRect).toSet(),
      hasLength(4),
    );
  });
}
