import 'package:patch_world/game/rooms/tiled/room_object_spec.dart';

abstract final class RoomMapValidator {
  static const Set<String> supportedClasses = <String>{
    'PlayerSpawn',
    'Wall',
    'EnemySpawn',
    'Terminal',
    'PhaseWall',
    'MergeZone',
    'LegacyTerminal',
    'HintTrigger',
  };

  static void validate(List<RoomObjectSpec> objects) {
    final ids = <String>{};
    var playerSpawnCount = 0;
    for (final object in objects) {
      if (!ids.add(object.id)) {
        throw FormatException('Duplicate Tiled object id: ${object.id}');
      }
      if (!supportedClasses.contains(object.objectClass)) {
        throw FormatException(
          'Unsupported Tiled class: ${object.objectClass} (${object.id})',
        );
      }
      if (object.objectClass == 'PlayerSpawn') playerSpawnCount += 1;
      if (object.objectClass == 'Wall' &&
          (object.size.x <= 0 || object.size.y <= 0)) {
        throw FormatException('Wall ${object.id} must have positive size.');
      }
      if (object.objectClass == 'EnemySpawn') {
        object.requireString('archetype');
        object.requireInt('spawnOrder');
      }
    }
    if (playerSpawnCount != 1) {
      throw FormatException(
        'Room requires exactly one PlayerSpawn; found $playerSpawnCount.',
      );
    }
  }
}
