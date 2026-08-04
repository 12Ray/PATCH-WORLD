import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rooms/tiled/room_map_validator.dart';
import 'package:patch_world/game/rooms/tiled/room_object_spec.dart';

void main() {
  RoomObjectSpec spec(String id, String objectClass) => RoomObjectSpec(
    tiledId: id.hashCode,
    id: id,
    objectClass: objectClass,
    position: Vector2.zero(),
    size: objectClass == 'Wall' ? Vector2.all(32) : Vector2.zero(),
    properties: objectClass == 'EnemySpawn'
        ? const <String, Object?>{'archetype': 'crawler', 'spawnOrder': 1}
        : const <String, Object?>{},
  );

  test('accepts one spawn and supported object classes', () {
    expect(
      () => RoomMapValidator.validate(<RoomObjectSpec>[
        spec('spawn', 'PlayerSpawn'),
        spec('wall', 'Wall'),
        spec('enemy', 'EnemySpawn'),
      ]),
      returnsNormally,
    );
  });

  test('rejects duplicate ids and missing player spawn', () {
    expect(
      () => RoomMapValidator.validate(<RoomObjectSpec>[
        spec('same', 'PlayerSpawn'),
        spec('same', 'Wall'),
      ]),
      throwsFormatException,
    );
    expect(
      () => RoomMapValidator.validate(<RoomObjectSpec>[spec('wall', 'Wall')]),
      throwsFormatException,
    );
  });
}
