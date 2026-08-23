import 'dart:ui';

/// One authored activation group in a campaign-room combat encounter.
///
/// Enemy ids reference the room's existing spawn catalog; a wave never owns
/// or duplicates spawn coordinates.
final class CampaignEncounterWaveSpec {
  const CampaignEncounterWaveSpec({required this.enemyIds});

  final List<String> enemyIds;
}

/// Camera framing to apply while an authored encounter is sealed.
final class CampaignCombatCameraSpec {
  const CampaignCombatCameraSpec({required this.zone, required this.zoom});

  final Rect zone;
  final double zoom;
}

/// Data-only pacing contract shared by every non-boss campaign room.
final class CampaignEncounterSpec {
  const CampaignEncounterSpec({
    required this.triggerZone,
    required this.waves,
    required this.intermissionSeconds,
    required this.sealSeconds,
    required this.clearBeatSeconds,
    required this.maxActiveEnemies,
    required this.combatCamera,
  });

  final Rect triggerZone;
  final List<CampaignEncounterWaveSpec> waves;
  final double intermissionSeconds;
  final double sealSeconds;
  final double clearBeatSeconds;
  final int maxActiveEnemies;
  final CampaignCombatCameraSpec combatCamera;

  Iterable<String> get enemyIds => waves.expand((wave) => wave.enemyIds);
}

/// Strict JSON parser for the shared campaign encounter sub-schema.
abstract final class CampaignEncounterSpecParser {
  static CampaignEncounterSpec parse(Object? value, String path) {
    final map = _requireMap(value, path);
    _rejectUnknownKeys(map, const <String>{
      'triggerZone',
      'waves',
      'intermissionSeconds',
      'sealSeconds',
      'clearBeatSeconds',
      'maxActiveEnemies',
      'combatCamera',
    }, path);

    final waves = _requireList(map, 'waves', path).indexed
        .map((entry) {
          final wavePath = '$path.waves[${entry.$1}]';
          final wave = _requireMap(entry.$2, wavePath);
          _rejectUnknownKeys(wave, const <String>{'enemyIds'}, wavePath);
          final enemyIds = _requireList(wave, 'enemyIds', wavePath).indexed
              .map((enemy) {
                if (enemy.$2 is! String || (enemy.$2 as String).isEmpty) {
                  throw FormatException(
                    '$wavePath.enemyIds[${enemy.$1}] must be a non-empty String.',
                  );
                }
                return enemy.$2 as String;
              })
              .toList(growable: false);
          return CampaignEncounterWaveSpec(
            enemyIds: List<String>.unmodifiable(enemyIds),
          );
        })
        .toList(growable: false);

    final cameraPath = '$path.combatCamera';
    final camera = _requireMap(
      _requireValue(map, 'combatCamera', path),
      cameraPath,
    );
    _rejectUnknownKeys(camera, const <String>{'zone', 'zoom'}, cameraPath);

    return CampaignEncounterSpec(
      triggerZone: _parseRect(
        _requireValue(map, 'triggerZone', path),
        '$path.triggerZone',
      ),
      waves: List<CampaignEncounterWaveSpec>.unmodifiable(waves),
      intermissionSeconds: _requireDouble(map, 'intermissionSeconds', path),
      sealSeconds: _requireDouble(map, 'sealSeconds', path),
      clearBeatSeconds: _requireDouble(map, 'clearBeatSeconds', path),
      maxActiveEnemies: _requireInt(map, 'maxActiveEnemies', path),
      combatCamera: CampaignCombatCameraSpec(
        zone: _parseRect(
          _requireValue(camera, 'zone', cameraPath),
          '$cameraPath.zone',
        ),
        zoom: _requireDouble(camera, 'zoom', cameraPath),
      ),
    );
  }

  static Map<String, Object?> _requireMap(Object? value, String path) {
    if (value is! Map) throw FormatException('$path must be an object.');
    try {
      return value.cast<String, Object?>();
    } on TypeError {
      throw FormatException('$path keys must be strings.');
    }
  }

  static List<Object?> _requireList(
    Map<String, Object?> map,
    String key,
    String path,
  ) {
    final value = _requireValue(map, key, path);
    if (value is! List) throw FormatException('$path.$key must be an array.');
    return value.cast<Object?>();
  }

  static Object? _requireValue(
    Map<String, Object?> map,
    String key,
    String path,
  ) {
    if (!map.containsKey(key)) {
      throw FormatException('$path is missing "$key".');
    }
    return map[key];
  }

  static int _requireInt(Map<String, Object?> map, String key, String path) {
    final value = _requireValue(map, key, path);
    if (value is! int) throw FormatException('$path.$key must be an int.');
    return value;
  }

  static double _requireDouble(
    Map<String, Object?> map,
    String key,
    String path,
  ) {
    final value = _requireValue(map, key, path);
    if (value is! num) throw FormatException('$path.$key must be a number.');
    return value.toDouble();
  }

  static Rect _parseRect(Object? value, String path) {
    if (value is! List ||
        value.length != 4 ||
        value.any((coordinate) => coordinate is! num)) {
      throw FormatException('$path must be a four-number array.');
    }
    return Rect.fromLTWH(
      (value[0] as num).toDouble(),
      (value[1] as num).toDouble(),
      (value[2] as num).toDouble(),
      (value[3] as num).toDouble(),
    );
  }

  static void _rejectUnknownKeys(
    Map<String, Object?> map,
    Set<String> allowed,
    String path,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw FormatException('$path contains unknown key "$key".');
      }
    }
  }
}

/// Cross-field validation for encounter pacing and room references.
abstract final class CampaignEncounterSpecValidator {
  static List<String> validate({
    required CampaignEncounterSpec encounter,
    required String roomLabel,
    required Rect roomBounds,
    required Map<String, Offset> enemyPositions,
    required Offset westEntry,
    required Offset eastEntry,
  }) {
    final errors = <String>[];
    final prefix = '$roomLabel encounter';

    if (!_hasPositiveSize(encounter.triggerZone) ||
        !_containsRect(roomBounds, encounter.triggerZone)) {
      errors.add('$prefix triggerZone must be positive and inside the room');
    }
    if (!_spansPlayableHeight(roomBounds, encounter.triggerZone)) {
      errors.add(
        '$prefix triggerZone must span the room playable height so it cannot '
        'be bypassed vertically',
      );
    }
    if (!(westEntry.dx < encounter.triggerZone.left &&
        eastEntry.dx > encounter.triggerZone.right)) {
      errors.add(
        '$prefix triggerZone must lie between west/east entry spawns for '
        'bidirectional entry',
      );
    }

    if (encounter.waves.length < 2) {
      errors.add('$prefix requires at least two waves');
    }
    final authoredIds = enemyPositions.keys.toSet();
    final assignedIds = <String>{};
    for (var index = 0; index < encounter.waves.length; index += 1) {
      final wave = encounter.waves[index];
      if (wave.enemyIds.isEmpty) {
        errors.add('$prefix wave $index must not be empty');
      }
      if (wave.enemyIds.length > encounter.maxActiveEnemies) {
        errors.add('$prefix wave $index exceeds maxActiveEnemies');
      }
      for (final enemyId in wave.enemyIds) {
        if (!authoredIds.contains(enemyId)) {
          errors.add('$prefix wave $index references unknown enemy "$enemyId"');
        }
        if (!assignedIds.add(enemyId)) {
          errors.add('$prefix assigns enemy "$enemyId" more than once');
        }
      }
    }
    final missingIds = authoredIds.difference(assignedIds).toList()..sort();
    if (missingIds.isNotEmpty) {
      errors.add('$prefix omits enemies ${missingIds.join(', ')}');
    }

    if (encounter.intermissionSeconds <= 0) {
      errors.add('$prefix intermissionSeconds must be positive');
    }
    if (encounter.sealSeconds <= 0) {
      errors.add('$prefix sealSeconds must be positive');
    }
    if (encounter.clearBeatSeconds <= 0) {
      errors.add('$prefix clearBeatSeconds must be positive');
    }
    if (encounter.maxActiveEnemies < 1 || encounter.maxActiveEnemies > 3) {
      errors.add('$prefix maxActiveEnemies must be between 1 and 3');
    }

    final camera = encounter.combatCamera;
    if (!_hasPositiveSize(camera.zone) ||
        !_containsRect(roomBounds, camera.zone)) {
      errors.add('$prefix combatCamera.zone must be positive and inside room');
    }
    if (!_containsRect(camera.zone, encounter.triggerZone)) {
      errors.add('$prefix combatCamera.zone must contain triggerZone');
    }
    if (camera.zoom <= 0) {
      errors.add('$prefix combatCamera.zoom must be positive');
    }
    for (final entry in enemyPositions.entries) {
      if (!camera.zone.contains(entry.value)) {
        errors.add(
          '$prefix combatCamera.zone does not contain enemy ${entry.key}',
        );
      }
    }
    return errors;
  }

  static bool _hasPositiveSize(Rect rect) => rect.width > 0 && rect.height > 0;

  static bool _spansPlayableHeight(Rect roomBounds, Rect triggerZone) =>
      triggerZone.top <= roomBounds.top &&
      triggerZone.bottom >= roomBounds.bottom;

  static bool _containsRect(Rect outer, Rect inner) =>
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;
}
