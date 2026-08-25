import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:patch_world/game/campaign/campaign_encounter_contract.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/ordinary_jump_reachability.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

/// Stable identifiers for authored points in the Damage Lab runtime map.
abstract final class DamageLabAnchorId {
  static const String backDoor = 'backDoor';
  static const String forwardDoor = 'forwardDoor';
  static const String checkpoint = 'checkpoint';
  static const String qaRecord = 'qaRecord';
  static const String repairStation = 'repairStation';
  static const String loadoutEvent = 'loadoutEvent';
  static const String maintenanceShortcut = 'maintenanceShortcut';
  static const String questReward = 'questReward';
  static const String bossSpawn = 'bossSpawn';
  static const String bossReward = 'bossReward';
  static const String exitTerminal = 'exitTerminal';
  static const String regionBranchDoor = 'regionBranchDoor';
}

enum DamageLabFeatureKind { jumpPad, pulsingLaser, spikeHazard, bossSeal }

final class DamageLabPointSpec {
  const DamageLabPointSpec(this.x, this.y);

  final double x;
  final double y;

  Vector2 toVector2() => Vector2(x, y);
}

final class DamageLabSurfaceSpec {
  const DamageLabSurfaceSpec({
    required this.id,
    required this.bounds,
    required this.isBoundary,
    required this.renderArtwork,
  });

  final String id;
  final Rect bounds;
  final bool isBoundary;
  final bool renderArtwork;
}

final class DamageLabEnemySpawnSpec {
  const DamageLabEnemySpawnSpec({
    required this.id,
    required this.archetype,
    required this.position,
  });

  final String id;
  final PlatformerEnemyArchetype archetype;
  final DamageLabPointSpec position;
}

final class DamageLabTraversalLinkSpec {
  const DamageLabTraversalLinkSpec({
    required this.fromSurfaceId,
    required this.toSurfaceId,
    required this.segment,
  });

  final String fromSurfaceId;
  final String toSurfaceId;
  final TraversalSegment segment;
}

final class DamageLabFeatureSpec {
  const DamageLabFeatureSpec({
    required this.id,
    required this.kind,
    required this.position,
    required this.size,
    this.sourceId,
    this.phaseOffset = 0,
  });

  final String id;
  final DamageLabFeatureKind kind;
  final DamageLabPointSpec position;
  final DamageLabPointSpec size;
  final String? sourceId;
  final double phaseOffset;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);
}

final class DamageLabSecretDoorSpec {
  const DamageLabSecretDoorSpec({required this.weapon, required this.position});

  final PlayerWeapon weapon;
  final DamageLabPointSpec position;
}

final class DamageLabTerrainPulseSpec {
  const DamageLabTerrainPulseSpec({
    required this.routeId,
    required this.bridgeBounds,
    required this.nodePosition,
  });

  final String routeId;
  final Rect bridgeBounds;
  final DamageLabPointSpec nodePosition;
}

/// Authored pressure hazard used only by the Overflow Warden arena.
final class DamageLabPressureVentSpec {
  const DamageLabPressureVentSpec({
    required this.id,
    required this.bounds,
    required this.activeFromPhase,
    required this.phaseOffset,
  });

  final String id;
  final Rect bounds;
  final int activeFromPhase;
  final double phaseOffset;
}

/// A boss-controlled platform. Its collision and solid artwork are enabled
/// together so the authored rectangle remains the sole gameplay coordinate.
final class DamageLabPhasePlatformSpec {
  const DamageLabPhasePlatformSpec({
    required this.id,
    required this.bounds,
    required this.activeFromPhase,
  });

  final String id;
  final Rect bounds;
  final int activeFromPhase;
}

final class DamageLabSafeZoneSpec {
  const DamageLabSafeZoneSpec({required this.id, required this.bounds});

  final String id;
  final Rect bounds;
}

final class DamageLabSummonGateSpec {
  const DamageLabSummonGateSpec({required this.id, required this.position});

  final String id;
  final DamageLabPointSpec position;
}

/// Data contract for the Warden's phase-reactive pressure hangar.
final class DamageLabBossMechanicSpec {
  const DamageLabBossMechanicSpec({
    required this.pressureVents,
    required this.phasePlatforms,
    required this.safeZones,
    required this.summonGates,
  });

  final List<DamageLabPressureVentSpec> pressureVents;
  final List<DamageLabPhasePlatformSpec> phasePlatforms;
  final List<DamageLabSafeZoneSpec> safeZones;
  final List<DamageLabSummonGateSpec> summonGates;
}

final class DamageLabCameraSpec {
  const DamageLabCameraSpec({
    required this.zoom,
    required this.horizontalLead,
    required this.horizontalDeadZone,
    required this.verticalDeadZone,
    required this.followResponsiveness,
  });

  final double zoom;
  final double horizontalLead;
  final double horizontalDeadZone;
  final double verticalDeadZone;
  final double followResponsiveness;
}

/// Immutable runtime representation of one authored Damage Lab room.
///
/// Rendering, collision, spawns, interactions, and traversal tests all read
/// this same object. The JSON asset is therefore the only coordinate source.
final class DamageLabRoomLayout {
  const DamageLabRoomLayout({
    required this.nodeId,
    required this.width,
    required this.height,
    required this.killPlaneY,
    required this.isBackdropAligned,
    required this.environmentAsset,
    required this.camera,
    required this.westSpawn,
    required this.eastSpawn,
    required this.anchors,
    required this.surfaces,
    required this.traversalLinks,
    required this.enemies,
    required this.encounter,
    required this.features,
    required this.secretDoors,
    required this.terrainPulse,
    required this.bossMechanic,
  });

  final CampaignNodeId nodeId;
  final double width;
  final double height;
  final double killPlaneY;
  final bool isBackdropAligned;
  final String? environmentAsset;
  final DamageLabCameraSpec camera;
  final DamageLabPointSpec westSpawn;
  final DamageLabPointSpec eastSpawn;
  final Map<String, DamageLabPointSpec> anchors;
  final List<DamageLabSurfaceSpec> surfaces;
  final List<DamageLabTraversalLinkSpec> traversalLinks;
  final List<DamageLabEnemySpawnSpec> enemies;
  final CampaignEncounterSpec? encounter;
  final List<DamageLabFeatureSpec> features;
  final List<DamageLabSecretDoorSpec> secretDoors;
  final DamageLabTerrainPulseSpec? terrainPulse;
  final DamageLabBossMechanicSpec? bossMechanic;

  Vector2 get size => Vector2(width, height);

  DamageLabPointSpec spawnFor(CampaignNodeEntry entry) =>
      entry == CampaignNodeEntry.west ? westSpawn : eastSpawn;

  DamageLabPointSpec? anchor(String id) => anchors[id];

  DamageLabPointSpec requireAnchor(String id) {
    final point = anchors[id];
    if (point == null) {
      throw StateError('${nodeId.name} is missing required anchor "$id".');
    }
    return point;
  }

  DamageLabSecretDoorSpec secretDoorFor(PlayerWeapon weapon) =>
      secretDoors.singleWhere((candidate) => candidate.weapon == weapon);

  List<TraversalSegment> get requiredTraversalSegments =>
      traversalLinks.map((link) => link.segment).toList(growable: false);
}

final class DamageLabRoomLayoutCatalog {
  DamageLabRoomLayoutCatalog._(this._rooms);

  static const String assetPath =
      'assets/tiles/maps/damage_lab_runtime_v1.json';

  final Map<CampaignNodeId, DamageLabRoomLayout> _rooms;

  Iterable<DamageLabRoomLayout> get rooms => _rooms.values;

  DamageLabRoomLayout room(CampaignNodeId nodeId) {
    final layout = _rooms[nodeId];
    if (layout == null) {
      throw StateError('No Damage Lab runtime layout for ${nodeId.name}.');
    }
    return layout;
  }

  static Future<DamageLabRoomLayoutCatalog> load({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    return fromJson(source);
  }

  static DamageLabRoomLayoutCatalog fromJson(String source) {
    final root = _requireMap(jsonDecode(source), 'root');
    _rejectUnknownKeys(root, const <String>{'schemaVersion', 'rooms'}, 'root');
    final schemaVersion = _requireInt(root, 'schemaVersion', 'root');
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported Damage Lab map schema $schemaVersion; expected 1.',
      );
    }
    final roomValues = _requireList(root, 'rooms', 'root');
    final rooms = <CampaignNodeId, DamageLabRoomLayout>{};
    for (var index = 0; index < roomValues.length; index += 1) {
      final path = 'rooms[$index]';
      final roomMap = _requireMap(roomValues[index], path);
      final layout = _parseRoom(roomMap, path);
      if (rooms.containsKey(layout.nodeId)) {
        throw FormatException(
          'Duplicate Damage Lab room ${layout.nodeId.name}.',
        );
      }
      rooms[layout.nodeId] = layout;
    }
    final catalog = DamageLabRoomLayoutCatalog._(Map.unmodifiable(rooms));
    DamageLabRoomLayoutValidator.validate(catalog);
    return catalog;
  }

  static DamageLabRoomLayout _parseRoom(Map<String, Object?> map, String path) {
    _rejectUnknownKeys(map, const <String>{
      'node',
      'size',
      'killPlaneY',
      'backdropAligned',
      'environmentAsset',
      'camera',
      'spawns',
      'anchors',
      'surfaces',
      'traversal',
      'enemies',
      'encounter',
      'features',
      'secretDoors',
      'terrainPulse',
      'bossMechanic',
    }, path);
    final nodeId = _enumByName(
      CampaignNodeId.values,
      _requireString(map, 'node', path),
      '$path.node',
    );
    final size = _parsePoint(_requireValue(map, 'size', path), '$path.size');
    final cameraMap = _requireMap(
      _requireValue(map, 'camera', path),
      '$path.camera',
    );
    _rejectUnknownKeys(cameraMap, const <String>{
      'zoom',
      'horizontalLead',
      'horizontalDeadZone',
      'verticalDeadZone',
      'followResponsiveness',
    }, '$path.camera');
    final spawnMap = _requireMap(
      _requireValue(map, 'spawns', path),
      '$path.spawns',
    );
    _rejectUnknownKeys(spawnMap, const <String>{
      'west',
      'east',
    }, '$path.spawns');
    final anchorMap = _requireMap(
      _requireValue(map, 'anchors', path),
      '$path.anchors',
    );
    final anchors = <String, DamageLabPointSpec>{};
    for (final entry in anchorMap.entries) {
      anchors[entry.key] = _parsePoint(
        entry.value,
        '$path.anchors.${entry.key}',
      );
    }

    final surfaces = _requireList(map, 'surfaces', path).indexed
        .map((entry) {
          final surfacePath = '$path.surfaces[${entry.$1}]';
          final surface = _requireMap(entry.$2, surfacePath);
          _rejectUnknownKeys(surface, const <String>{
            'id',
            'rect',
            'boundary',
            'renderArtwork',
          }, surfacePath);
          return DamageLabSurfaceSpec(
            id: _requireString(surface, 'id', surfacePath),
            bounds: _parseRect(
              _requireValue(surface, 'rect', surfacePath),
              '$surfacePath.rect',
            ),
            isBoundary: _optionalBool(surface, 'boundary', false, surfacePath),
            renderArtwork: _optionalBool(
              surface,
              'renderArtwork',
              true,
              surfacePath,
            ),
          );
        })
        .toList(growable: false);

    final surfacesById = <String, DamageLabSurfaceSpec>{
      for (final surface in surfaces) surface.id: surface,
    };
    final traversal = _requireList(map, 'traversal', path).indexed
        .map((entry) {
          final segmentPath = '$path.traversal[${entry.$1}]';
          final segment = _requireMap(entry.$2, segmentPath);
          _rejectUnknownKeys(segment, const <String>{
            'id',
            'fromSurfaceId',
            'toSurfaceId',
            'requiredForCompletion',
            'requirement',
            'requiresMovingPlatform',
            'requiresBreakablePlatform',
          }, segmentPath);
          final fromSurfaceId = _requireString(
            segment,
            'fromSurfaceId',
            segmentPath,
          );
          final toSurfaceId = _requireString(
            segment,
            'toSurfaceId',
            segmentPath,
          );
          final fromSurface = surfacesById[fromSurfaceId];
          final toSurface = surfacesById[toSurfaceId];
          if (fromSurface == null) {
            throw FormatException(
              '$segmentPath.fromSurfaceId references "$fromSurfaceId", '
              'which is not authored in this room.',
            );
          }
          if (toSurface == null) {
            throw FormatException(
              '$segmentPath.toSurfaceId references "$toSurfaceId", '
              'which is not authored in this room.',
            );
          }
          final requirementName = _optionalString(
            segment,
            'requirement',
            TraversalAbilityRequirement.universal.name,
            segmentPath,
          );
          return DamageLabTraversalLinkSpec(
            fromSurfaceId: fromSurfaceId,
            toSurfaceId: toSurfaceId,
            segment: TraversalSegment(
              id: _requireString(segment, 'id', segmentPath),
              rise: (fromSurface.bounds.top - toSurface.bounds.top).abs(),
              gap: _horizontalGap(fromSurface.bounds, toSurface.bounds),
              landingWidth: toSurface.bounds.width,
              requiredForCompletion: _optionalBool(
                segment,
                'requiredForCompletion',
                true,
                segmentPath,
              ),
              requirement: _enumByName(
                TraversalAbilityRequirement.values,
                requirementName,
                '$segmentPath.requirement',
              ),
              requiresMovingPlatform: _optionalBool(
                segment,
                'requiresMovingPlatform',
                false,
                segmentPath,
              ),
              requiresBreakablePlatform: _optionalBool(
                segment,
                'requiresBreakablePlatform',
                false,
                segmentPath,
              ),
            ),
          );
        })
        .toList(growable: false);

    final enemies = _requireList(map, 'enemies', path).indexed
        .map((entry) {
          final enemyPath = '$path.enemies[${entry.$1}]';
          final enemy = _requireMap(entry.$2, enemyPath);
          _rejectUnknownKeys(enemy, const <String>{
            'id',
            'archetype',
            'position',
          }, enemyPath);
          return DamageLabEnemySpawnSpec(
            id: _requireString(enemy, 'id', enemyPath),
            archetype: _enumByName(
              PlatformerEnemyArchetype.values,
              _requireString(enemy, 'archetype', enemyPath),
              '$enemyPath.archetype',
            ),
            position: _parsePoint(
              _requireValue(enemy, 'position', enemyPath),
              '$enemyPath.position',
            ),
          );
        })
        .toList(growable: false);

    final encounterValue = _requireValue(map, 'encounter', path);
    final encounter = encounterValue == null
        ? null
        : CampaignEncounterSpecParser.parse(encounterValue, '$path.encounter');

    final features = _requireList(map, 'features', path).indexed
        .map((entry) {
          final featurePath = '$path.features[${entry.$1}]';
          final feature = _requireMap(entry.$2, featurePath);
          _rejectUnknownKeys(feature, const <String>{
            'id',
            'kind',
            'position',
            'size',
            'sourceId',
            'phaseOffset',
          }, featurePath);
          final sourceId = feature['sourceId'];
          if (sourceId != null && sourceId is! String) {
            throw FormatException('$featurePath.sourceId must be a String.');
          }
          return DamageLabFeatureSpec(
            id: _requireString(feature, 'id', featurePath),
            kind: _enumByName(
              DamageLabFeatureKind.values,
              _requireString(feature, 'kind', featurePath),
              '$featurePath.kind',
            ),
            position: _parsePoint(
              _requireValue(feature, 'position', featurePath),
              '$featurePath.position',
            ),
            size: feature.containsKey('size')
                ? _parsePoint(feature['size'], '$featurePath.size')
                : const DamageLabPointSpec(0, 0),
            sourceId: sourceId as String?,
            phaseOffset: feature.containsKey('phaseOffset')
                ? _requireDouble(feature, 'phaseOffset', featurePath)
                : 0,
          );
        })
        .toList(growable: false);

    final secretDoors = _requireList(map, 'secretDoors', path).indexed
        .map((entry) {
          final doorPath = '$path.secretDoors[${entry.$1}]';
          final door = _requireMap(entry.$2, doorPath);
          _rejectUnknownKeys(door, const <String>{
            'weapon',
            'position',
          }, doorPath);
          return DamageLabSecretDoorSpec(
            weapon: _enumByName(
              PlayerWeapon.values,
              _requireString(door, 'weapon', doorPath),
              '$doorPath.weapon',
            ),
            position: _parsePoint(
              _requireValue(door, 'position', doorPath),
              '$doorPath.position',
            ),
          );
        })
        .toList(growable: false);

    DamageLabTerrainPulseSpec? terrainPulse;
    if (map['terrainPulse'] != null) {
      final pulse = _requireMap(map['terrainPulse'], '$path.terrainPulse');
      _rejectUnknownKeys(pulse, const <String>{
        'routeId',
        'bridge',
        'node',
      }, '$path.terrainPulse');
      terrainPulse = DamageLabTerrainPulseSpec(
        routeId: _requireString(pulse, 'routeId', '$path.terrainPulse'),
        bridgeBounds: _parseRect(
          _requireValue(pulse, 'bridge', '$path.terrainPulse'),
          '$path.terrainPulse.bridge',
        ),
        nodePosition: _parsePoint(
          _requireValue(pulse, 'node', '$path.terrainPulse'),
          '$path.terrainPulse.node',
        ),
      );
    }

    final bossMechanic = map['bossMechanic'] == null
        ? null
        : _parseBossMechanic(map['bossMechanic'], '$path.bossMechanic');

    final backdrop = map['environmentAsset'];
    if (backdrop != null && backdrop is! String) {
      throw FormatException('$path.environmentAsset must be a String.');
    }
    return DamageLabRoomLayout(
      nodeId: nodeId,
      width: size.x,
      height: size.y,
      killPlaneY: _requireDouble(map, 'killPlaneY', path),
      isBackdropAligned: _requireBool(map, 'backdropAligned', path),
      environmentAsset: backdrop as String?,
      camera: DamageLabCameraSpec(
        zoom: _requireDouble(cameraMap, 'zoom', '$path.camera'),
        horizontalLead: _requireDouble(
          cameraMap,
          'horizontalLead',
          '$path.camera',
        ),
        horizontalDeadZone: _requireDouble(
          cameraMap,
          'horizontalDeadZone',
          '$path.camera',
        ),
        verticalDeadZone: _requireDouble(
          cameraMap,
          'verticalDeadZone',
          '$path.camera',
        ),
        followResponsiveness: _requireDouble(
          cameraMap,
          'followResponsiveness',
          '$path.camera',
        ),
      ),
      westSpawn: _parsePoint(
        _requireValue(spawnMap, 'west', '$path.spawns'),
        '$path.spawns.west',
      ),
      eastSpawn: _parsePoint(
        _requireValue(spawnMap, 'east', '$path.spawns'),
        '$path.spawns.east',
      ),
      anchors: Map.unmodifiable(anchors),
      surfaces: List.unmodifiable(surfaces),
      traversalLinks: List.unmodifiable(traversal),
      enemies: List.unmodifiable(enemies),
      encounter: encounter,
      features: List.unmodifiable(features),
      secretDoors: List.unmodifiable(secretDoors),
      terrainPulse: terrainPulse,
      bossMechanic: bossMechanic,
    );
  }

  static DamageLabBossMechanicSpec _parseBossMechanic(
    Object? value,
    String path,
  ) {
    final mechanic = _requireMap(value, path);
    _rejectUnknownKeys(mechanic, const <String>{
      'pressureVents',
      'phasePlatforms',
      'safeZones',
      'summonGates',
    }, path);

    final pressureVents = _requireList(mechanic, 'pressureVents', path).indexed
        .map((entry) {
          final itemPath = '$path.pressureVents[${entry.$1}]';
          final item = _requireMap(entry.$2, itemPath);
          _rejectUnknownKeys(item, const <String>{
            'id',
            'rect',
            'activeFromPhase',
            'phaseOffset',
          }, itemPath);
          return DamageLabPressureVentSpec(
            id: _requireString(item, 'id', itemPath),
            bounds: _parseRect(
              _requireValue(item, 'rect', itemPath),
              '$itemPath.rect',
            ),
            activeFromPhase: _requireInt(item, 'activeFromPhase', itemPath),
            phaseOffset: item.containsKey('phaseOffset')
                ? _requireDouble(item, 'phaseOffset', itemPath)
                : 0,
          );
        })
        .toList(growable: false);

    final phasePlatforms = _requireList(mechanic, 'phasePlatforms', path)
        .indexed
        .map((entry) {
          final itemPath = '$path.phasePlatforms[${entry.$1}]';
          final item = _requireMap(entry.$2, itemPath);
          _rejectUnknownKeys(item, const <String>{
            'id',
            'rect',
            'activeFromPhase',
          }, itemPath);
          return DamageLabPhasePlatformSpec(
            id: _requireString(item, 'id', itemPath),
            bounds: _parseRect(
              _requireValue(item, 'rect', itemPath),
              '$itemPath.rect',
            ),
            activeFromPhase: _requireInt(item, 'activeFromPhase', itemPath),
          );
        })
        .toList(growable: false);

    final safeZones = _requireList(mechanic, 'safeZones', path).indexed
        .map((entry) {
          final itemPath = '$path.safeZones[${entry.$1}]';
          final item = _requireMap(entry.$2, itemPath);
          _rejectUnknownKeys(item, const <String>{'id', 'rect'}, itemPath);
          return DamageLabSafeZoneSpec(
            id: _requireString(item, 'id', itemPath),
            bounds: _parseRect(
              _requireValue(item, 'rect', itemPath),
              '$itemPath.rect',
            ),
          );
        })
        .toList(growable: false);

    final summonGates = _requireList(mechanic, 'summonGates', path).indexed
        .map((entry) {
          final itemPath = '$path.summonGates[${entry.$1}]';
          final item = _requireMap(entry.$2, itemPath);
          _rejectUnknownKeys(item, const <String>{'id', 'position'}, itemPath);
          return DamageLabSummonGateSpec(
            id: _requireString(item, 'id', itemPath),
            position: _parsePoint(
              _requireValue(item, 'position', itemPath),
              '$itemPath.position',
            ),
          );
        })
        .toList(growable: false);

    return DamageLabBossMechanicSpec(
      pressureVents: List.unmodifiable(pressureVents),
      phasePlatforms: List.unmodifiable(phasePlatforms),
      safeZones: List.unmodifiable(safeZones),
      summonGates: List.unmodifiable(summonGates),
    );
  }

  static DamageLabPointSpec _parsePoint(Object? value, String path) {
    if (value is! List || value.length != 2) {
      throw FormatException('$path must be a two-number array.');
    }
    final x = value[0];
    final y = value[1];
    if (x is! num || y is! num) {
      throw FormatException('$path must contain only numbers.');
    }
    return DamageLabPointSpec(x.toDouble(), y.toDouble());
  }

  static Rect _parseRect(Object? value, String path) {
    if (value is! List || value.length != 4) {
      throw FormatException('$path must be a four-number array.');
    }
    if (value.any((coordinate) => coordinate is! num)) {
      throw FormatException('$path must contain only numbers.');
    }
    return Rect.fromLTWH(
      (value[0] as num).toDouble(),
      (value[1] as num).toDouble(),
      (value[2] as num).toDouble(),
      (value[3] as num).toDouble(),
    );
  }

  static double _horizontalGap(Rect from, Rect to) {
    if (from.right < to.left) return to.left - from.right;
    if (to.right < from.left) return from.left - to.right;
    return 0;
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

  static String _requireString(
    Map<String, Object?> map,
    String key,
    String path,
  ) {
    final value = _requireValue(map, key, path);
    if (value is! String || value.isEmpty) {
      throw FormatException('$path.$key must be a non-empty String.');
    }
    return value;
  }

  static String _optionalString(
    Map<String, Object?> map,
    String key,
    String fallback,
    String path,
  ) {
    if (!map.containsKey(key)) return fallback;
    return _requireString(map, key, path);
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

  static bool _requireBool(Map<String, Object?> map, String key, String path) {
    final value = _requireValue(map, key, path);
    if (value is! bool) throw FormatException('$path.$key must be a bool.');
    return value;
  }

  static bool _optionalBool(
    Map<String, Object?> map,
    String key,
    bool fallback,
    String path,
  ) {
    if (!map.containsKey(key)) return fallback;
    return _requireBool(map, key, path);
  }

  static T _enumByName<T extends Enum>(
    Iterable<T> values,
    String name,
    String path,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('$path has unsupported value "$name".');
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

abstract final class DamageLabRoomLayoutValidator {
  static const Set<CampaignNodeId> requiredNodes = <CampaignNodeId>{
    CampaignNodeId.damageWorkshop,
    CampaignNodeId.damageAssembly,
    CampaignNodeId.damageOverflow,
    CampaignNodeId.overflowWarden,
  };

  static void validate(DamageLabRoomLayoutCatalog catalog) {
    final errors = <String>[];
    final actualNodes = catalog.rooms.map((room) => room.nodeId).toSet();
    if (!actualNodes.containsAll(requiredNodes) ||
        actualNodes.length != requiredNodes.length) {
      errors.add(
        'rooms must be exactly ${requiredNodes.map((node) => node.name).join(', ')}',
      );
    }
    for (final room in catalog.rooms) {
      _validateRoom(room, errors);
    }
    if (errors.isNotEmpty) {
      throw FormatException(
        'Invalid Damage Lab runtime map:\n- ${errors.join('\n- ')}',
      );
    }
  }

  static void _validateRoom(DamageLabRoomLayout room, List<String> errors) {
    final prefix = room.nodeId.name;
    if (room.width <= 0 || room.height <= 0) {
      errors.add('$prefix has a non-positive room size');
    }
    if (room.killPlaneY <= room.height) {
      errors.add('$prefix kill plane must be below the room');
    }
    if (room.isBackdropAligned &&
        (room.environmentAsset == null || room.environmentAsset!.isEmpty)) {
      errors.add('$prefix backdrop-aligned room requires environmentAsset');
    }
    if (!room.isBackdropAligned && room.environmentAsset != null) {
      errors.add('$prefix procedural room must not declare environmentAsset');
    }

    final ids = <String>{};
    void addId(String id, String kind) {
      if (id.isEmpty) errors.add('$prefix has an empty $kind id');
      if (!ids.add(id)) errors.add('$prefix duplicates object id "$id"');
    }

    for (final surface in room.surfaces) {
      addId(surface.id, 'surface');
      if (surface.bounds.width <= 0 || surface.bounds.height <= 0) {
        errors.add('$prefix surface ${surface.id} has non-positive size');
      }
      if (!_containsRect(room, surface.bounds)) {
        errors.add('$prefix surface ${surface.id} is outside the room');
      }
      if (room.isBackdropAligned &&
          !surface.isBoundary &&
          surface.renderArtwork) {
        errors.add(
          '$prefix surface ${surface.id} duplicates authored backdrop art',
        );
      }
      if (!room.isBackdropAligned &&
          !surface.isBoundary &&
          !surface.renderArtwork) {
        errors.add(
          '$prefix surface ${surface.id} hides a collidable story surface',
        );
      }
      if (surface.isBoundary && surface.renderArtwork) {
        errors.add('$prefix boundary ${surface.id} must not render artwork');
      }
    }
    for (final link in room.traversalLinks) {
      addId(link.segment.id, 'traversal link');
    }
    for (final enemy in room.enemies) {
      addId(enemy.id, 'enemy');
      if (!_containsPoint(room, enemy.position)) {
        errors.add('$prefix enemy ${enemy.id} is outside the room');
      }
      if (!_hasSupport(room, enemy.position, verticalOffset: 36)) {
        errors.add('$prefix enemy ${enemy.id} has no authored landing');
      }
    }
    for (final feature in room.features) {
      addId(feature.id, 'feature');
      if (!_containsPoint(room, feature.position)) {
        errors.add('$prefix feature ${feature.id} is outside the room');
      }
      if ((feature.kind == DamageLabFeatureKind.pulsingLaser ||
              feature.kind == DamageLabFeatureKind.spikeHazard ||
              feature.kind == DamageLabFeatureKind.bossSeal) &&
          (feature.size.x <= 0 || feature.size.y <= 0)) {
        errors.add('$prefix feature ${feature.id} requires positive size');
      }
      if (feature.size.x > 0 &&
          feature.size.y > 0 &&
          !_containsRect(room, feature.bounds)) {
        errors.add('$prefix feature ${feature.id} exceeds room bounds');
      }
      if ((feature.kind == DamageLabFeatureKind.pulsingLaser ||
              feature.kind == DamageLabFeatureKind.spikeHazard) &&
          (feature.sourceId == null || feature.sourceId!.isEmpty)) {
        errors.add('$prefix hazard ${feature.id} requires sourceId');
      }
    }

    final hazardSourceIds = <String>{};
    for (final feature in room.features.where(
      (feature) =>
          feature.kind == DamageLabFeatureKind.pulsingLaser ||
          feature.kind == DamageLabFeatureKind.spikeHazard,
    )) {
      final sourceId = feature.sourceId;
      if (sourceId != null && !hazardSourceIds.add(sourceId)) {
        errors.add('$prefix duplicates hazard sourceId "$sourceId"');
      }
    }

    for (final entry in room.anchors.entries) {
      if (!_containsPoint(room, entry.value)) {
        errors.add('$prefix anchor ${entry.key} is outside the room');
      }
    }
    for (final spawn in <DamageLabPointSpec>[room.westSpawn, room.eastSpawn]) {
      if (!_containsPoint(room, spawn)) {
        errors.add('$prefix player spawn is outside the room');
      } else if (!_hasSupport(room, spawn, verticalOffset: 36)) {
        errors.add('$prefix player spawn has no authored landing');
      }
    }

    for (final requiredAnchor in <String>[
      DamageLabAnchorId.backDoor,
      if (room.nodeId != CampaignNodeId.overflowWarden)
        DamageLabAnchorId.forwardDoor,
    ]) {
      final anchor = room.anchor(requiredAnchor);
      if (anchor == null) {
        errors.add('$prefix is missing $requiredAnchor');
      } else if (!_hasSupport(room, anchor)) {
        errors.add('$prefix $requiredAnchor has no authored landing');
      }
    }

    for (final weapon in PlayerWeapon.values) {
      for (final violation in PlatformerTraversalContract.validateRequiredRoute(
        room.requiredTraversalSegments,
        weapon: weapon,
      )) {
        errors.add('$prefix/${weapon.name}: $violation');
      }
    }

    final backDoor = room.anchor(DamageLabAnchorId.backDoor);
    final forwardDoor = room.anchor(DamageLabAnchorId.forwardDoor);
    if (forwardDoor != null &&
        !_hasRequiredRoute(
          room,
          start: room.westSpawn,
          startOffset: 36,
          destination: forwardDoor,
        )) {
      errors.add('$prefix west spawn cannot reach the forward door');
    }
    if (backDoor != null &&
        !_hasRequiredRoute(
          room,
          start: room.eastSpawn,
          startOffset: 36,
          destination: backDoor,
        )) {
      errors.add('$prefix east spawn cannot reach the back door');
    }

    _validateRequiredOrdinaryJumpTransitions(room, errors);

    if (room.nodeId == CampaignNodeId.damageAssembly) {
      if (room.secretDoors.length != PlayerWeapon.values.length ||
          PlayerWeapon.values.any(
            (weapon) =>
                room.secretDoors
                    .where((door) => door.weapon == weapon)
                    .length !=
                1,
          )) {
        errors.add('$prefix must author one secret door per weapon');
      }
      for (final door in room.secretDoors) {
        if (!_containsPoint(room, door.position)) {
          errors.add('$prefix ${door.weapon.name} secret door is outside');
        } else if (!_hasSupport(room, door.position)) {
          errors.add(
            '$prefix ${door.weapon.name} secret door has no authored landing',
          );
        }
      }
      if (room.terrainPulse == null) {
        errors.add('$prefix requires the terrain pulse route');
      } else {
        final pulse = room.terrainPulse!;
        if (pulse.routeId.isEmpty) {
          errors.add('$prefix terrain pulse requires a routeId');
        }
        if (!_containsRect(room, pulse.bridgeBounds)) {
          errors.add('$prefix terrain pulse bridge is outside the room');
        }
        if (!_containsPoint(room, pulse.nodePosition)) {
          errors.add('$prefix terrain pulse node is outside the room');
        } else if (!_hasSupport(room, pulse.nodePosition, verticalOffset: 12)) {
          errors.add('$prefix terrain pulse node has no authored landing');
        }
      }
    } else {
      if (room.secretDoors.isNotEmpty) {
        errors.add('$prefix must not author weapon cache doors');
      }
      if (room.terrainPulse != null) {
        errors.add('$prefix must not author a terrain pulse route');
      }
    }

    if (room.nodeId == CampaignNodeId.overflowWarden) {
      if (room.encounter != null) {
        errors.add('$prefix boss room encounter must be null');
      }
      if (room.width < 1440 || room.height < 832) {
        errors.add('$prefix boss hangar must be at least 1440x832');
      }
      for (final id in <String>[
        DamageLabAnchorId.bossSpawn,
        DamageLabAnchorId.bossReward,
        DamageLabAnchorId.exitTerminal,
        DamageLabAnchorId.regionBranchDoor,
      ]) {
        if (room.anchor(id) == null) errors.add('$prefix is missing $id');
      }
      final bossSpawn = room.anchor(DamageLabAnchorId.bossSpawn);
      if (bossSpawn != null &&
          !_hasSupport(room, bossSpawn, verticalOffset: 56)) {
        errors.add('$prefix boss spawn has no authored landing');
      }
      for (final id in <String>[
        DamageLabAnchorId.bossReward,
        DamageLabAnchorId.exitTerminal,
      ]) {
        final anchor = room.anchor(id);
        if (anchor != null && !_hasSupport(room, anchor, verticalOffset: 6)) {
          errors.add('$prefix $id has no authored landing');
        }
      }
      final branch = room.anchor(DamageLabAnchorId.regionBranchDoor);
      if (branch != null && !_hasSupport(room, branch)) {
        errors.add('$prefix regionBranchDoor has no authored landing');
      }
      if (room.features
              .where((feature) => feature.kind == DamageLabFeatureKind.bossSeal)
              .length !=
          2) {
        errors.add('$prefix requires exactly two boss seals');
      }
      final mechanic = room.bossMechanic;
      if (mechanic == null) {
        errors.add('$prefix requires a bossMechanic contract');
      } else {
        _validateBossMechanic(room, mechanic, errors, addId);
      }
    } else {
      if (room.bossMechanic != null) {
        errors.add('$prefix must not declare bossMechanic');
      }
      final encounter = room.encounter;
      if (encounter == null) {
        errors.add('$prefix requires an encounter contract');
      } else {
        errors.addAll(
          CampaignEncounterSpecValidator.validate(
            encounter: encounter,
            roomLabel: prefix,
            roomBounds: Rect.fromLTWH(0, 0, room.width, room.height),
            enemyPositions: <String, Offset>{
              for (final enemy in room.enemies)
                enemy.id: Offset(enemy.position.x, enemy.position.y),
            },
            westEntry: Offset(room.westSpawn.x, room.westSpawn.y),
            eastEntry: Offset(room.eastSpawn.x, room.eastSpawn.y),
          ),
        );
      }
      if (room.anchor(DamageLabAnchorId.qaRecord) == null) {
        errors.add('$prefix is missing qaRecord');
      }
      if (room.enemies.isEmpty) errors.add('$prefix has no combat encounter');
      final qaRecord = room.anchor(DamageLabAnchorId.qaRecord);
      if (qaRecord != null && !_hasSupport(room, qaRecord, verticalOffset: 6)) {
        errors.add('$prefix qaRecord has no authored landing');
      }
      for (final id in <String>[
        DamageLabAnchorId.checkpoint,
        DamageLabAnchorId.repairStation,
        DamageLabAnchorId.maintenanceShortcut,
      ]) {
        final anchor = room.anchor(id);
        if (anchor != null && !_hasSupport(room, anchor)) {
          errors.add('$prefix $id has no authored landing');
        }
      }
      final questReward = room.anchor(DamageLabAnchorId.questReward);
      if (questReward != null &&
          !_hasSupport(room, questReward, verticalOffset: 6)) {
        errors.add('$prefix questReward has no authored landing');
      }
    }
  }

  static void _validateBossMechanic(
    DamageLabRoomLayout room,
    DamageLabBossMechanicSpec mechanic,
    List<String> errors,
    void Function(String id, String kind) addId,
  ) {
    final prefix = room.nodeId.name;
    if (mechanic.pressureVents.length < 3) {
      errors.add('$prefix requires at least three pressure vents');
    }
    if (mechanic.phasePlatforms.length < 2) {
      errors.add('$prefix requires at least two phase platforms');
    }
    if (mechanic.safeZones.length < 2) {
      errors.add('$prefix requires at least two authored safe zones');
    }
    if (mechanic.summonGates.length < 2) {
      errors.add('$prefix requires at least two summon gates');
    }

    for (final vent in mechanic.pressureVents) {
      addId(vent.id, 'pressure vent');
      if (vent.bounds.isEmpty || !_containsRect(room, vent.bounds)) {
        errors.add('$prefix pressure vent ${vent.id} has invalid bounds');
      }
      if (vent.activeFromPhase < 2 || vent.activeFromPhase > 3) {
        errors.add(
          '$prefix pressure vent ${vent.id} activeFromPhase must be 2 or 3',
        );
      }
    }
    for (final platform in mechanic.phasePlatforms) {
      addId(platform.id, 'phase platform');
      if (platform.bounds.isEmpty || !_containsRect(room, platform.bounds)) {
        errors.add('$prefix phase platform ${platform.id} has invalid bounds');
      }
      if (platform.activeFromPhase < 2 || platform.activeFromPhase > 3) {
        errors.add(
          '$prefix phase platform ${platform.id} activeFromPhase must be 2 or 3',
        );
      }
      if (room.surfaces.any(
        (surface) =>
            !surface.isBoundary && surface.bounds.overlaps(platform.bounds),
      )) {
        errors.add(
          '$prefix phase platform ${platform.id} overlaps static collision',
        );
      }
    }
    for (final zone in mechanic.safeZones) {
      addId(zone.id, 'safe zone');
      if (zone.bounds.isEmpty || !_containsRect(room, zone.bounds)) {
        errors.add('$prefix safe zone ${zone.id} has invalid bounds');
      }
      if (mechanic.pressureVents.any(
        (vent) => vent.bounds.overlaps(zone.bounds),
      )) {
        errors.add('$prefix safe zone ${zone.id} overlaps a pressure vent');
      }
    }
    for (final gate in mechanic.summonGates) {
      addId(gate.id, 'summon gate');
      if (!_containsPoint(room, gate.position)) {
        errors.add('$prefix summon gate ${gate.id} is outside the room');
      } else if (!_hasSupport(room, gate.position, verticalOffset: 36)) {
        errors.add('$prefix summon gate ${gate.id} has no authored landing');
      }
    }
  }

  static bool _containsPoint(
    DamageLabRoomLayout room,
    DamageLabPointSpec point,
  ) =>
      point.x >= 0 &&
      point.y >= 0 &&
      point.x <= room.width &&
      point.y <= room.height;

  static bool _containsRect(DamageLabRoomLayout room, Rect rect) =>
      rect.left >= 0 &&
      rect.top >= 0 &&
      rect.right <= room.width &&
      rect.bottom <= room.height;

  static bool _hasSupport(
    DamageLabRoomLayout room,
    DamageLabPointSpec point, {
    double verticalOffset = 0,
  }) {
    final feetY = point.y + verticalOffset;
    return room.surfaces.any(
      (surface) =>
          !surface.isBoundary &&
          point.x >= surface.bounds.left &&
          point.x <= surface.bounds.right &&
          (surface.bounds.top - feetY).abs() <= .01,
    );
  }

  static bool _hasRequiredRoute(
    DamageLabRoomLayout room, {
    required DamageLabPointSpec start,
    required double startOffset,
    required DamageLabPointSpec destination,
  }) {
    final starts = _supportSurfaceIds(room, start, verticalOffset: startOffset);
    final destinations = _supportSurfaceIds(room, destination);
    if (starts.isEmpty || destinations.isEmpty) return false;

    final adjacency = <String, Set<String>>{};
    for (final link in room.traversalLinks.where(
      (candidate) => candidate.segment.requiredForCompletion,
    )) {
      adjacency
          .putIfAbsent(link.fromSurfaceId, () => <String>{})
          .add(link.toSurfaceId);
      adjacency
          .putIfAbsent(link.toSurfaceId, () => <String>{})
          .add(link.fromSurfaceId);
    }
    final visited = <String>{...starts};
    final pending = <String>[...starts];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (destinations.contains(current)) return true;
      for (final next in adjacency[current] ?? const <String>{}) {
        if (visited.add(next)) pending.add(next);
      }
    }
    return false;
  }

  /// Keeps production map parsing inexpensive while still checking every
  /// authored mandatory edge against the real sword jump arc and intervening
  /// collision. Full spawn-to-anchor graph searches live in deterministic QA
  /// tests because they intentionally sample all static surface pairs.
  static void _validateRequiredOrdinaryJumpTransitions(
    DamageLabRoomLayout room,
    List<String> errors,
  ) {
    final surfaces = room.surfaces
        .where((surface) => !surface.isBoundary)
        .map(
          (surface) =>
              OrdinaryJumpSurface(id: surface.id, bounds: surface.bounds),
        )
        .toList(growable: false);
    final byId = <String, OrdinaryJumpSurface>{
      for (final surface in surfaces) surface.id: surface,
    };
    for (final link in room.traversalLinks.where(
      (link) => link.segment.requiredForCompletion,
    )) {
      final from = byId[link.fromSurfaceId];
      final to = byId[link.toSurfaceId];
      if (from == null || to == null) continue;
      for (final direction
          in <(String, OrdinaryJumpSurface, OrdinaryJumpSurface)>[
            ('forward', from, to),
            ('reverse', to, from),
          ]) {
        if (OrdinaryJumpReachability.transition(
              direction.$2,
              direction.$3,
              collisionSurfaces: surfaces,
            ) ==
            null) {
          errors.add(
            '${room.nodeId.name}/${link.segment.id} ${direction.$1} is '
            'blocked for ordinary sword movement',
          );
        }
      }
    }
  }

  static Set<String> _supportSurfaceIds(
    DamageLabRoomLayout room,
    DamageLabPointSpec point, {
    double verticalOffset = 0,
  }) {
    final feetY = point.y + verticalOffset;
    return room.surfaces
        .where(
          (surface) =>
              !surface.isBoundary &&
              point.x >= surface.bounds.left &&
              point.x <= surface.bounds.right &&
              (surface.bounds.top - feetY).abs() <= .01,
        )
        .map((surface) => surface.id)
        .toSet();
  }
}
