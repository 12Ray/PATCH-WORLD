import 'dart:convert';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:patch_world/game/campaign/campaign_encounter_contract.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/campaign/regional_room_objective.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

/// Stable placement sockets shared by the Temporal Hall and Collision Archive
/// runtime maps. Campaign topology and unlock rules deliberately remain in
/// [CampaignWorldGraph]; the map assets own placement and tuning only.
abstract final class RegionalCampaignAnchorId {
  static const String backDoor = 'backDoor';
  static const String forwardDoor = 'forwardDoor';
  static const String checkpoint = 'checkpoint';
  static const String qaRecord = 'qaRecord';
  static const String repairStation = 'repairStation';
  static const String loadoutEvent = 'loadoutEvent';
  static const String hubShortcutDoor = 'hubShortcutDoor';
  static const String secretDoor = 'secretDoor';
  static const String questReward = 'questReward';
  static const String bossSpawn = 'bossSpawn';
  static const String bossReward = 'bossReward';
  static const String exitTerminal = 'exitTerminal';
  static const String hubLift = 'hubLift';
  static const String regionBranchDoor = 'regionBranchDoor';
}

enum RegionalCampaignFeatureKind {
  movingPlatform,
  rewindPlatform,
  mergingPlatform,
  conveyorPlatform,
  breakablePlatform,
  jumpPad,
  pulsingLaser,
  crusherHazard,
  spikeHazard,
  bossSeal,
}

final class RegionalCampaignPointSpec {
  const RegionalCampaignPointSpec(this.x, this.y);

  final double x;
  final double y;

  Vector2 toVector2() => Vector2(x, y);
}

final class RegionalCampaignCameraSpec {
  const RegionalCampaignCameraSpec({
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

final class RegionalCampaignSurfaceSpec {
  const RegionalCampaignSurfaceSpec({
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

final class RegionalCampaignEnemySpawnSpec {
  const RegionalCampaignEnemySpawnSpec({
    required this.id,
    required this.archetype,
    required this.position,
  });

  final String id;
  final PlatformerEnemyArchetype archetype;
  final RegionalCampaignPointSpec position;
}

final class RegionalCampaignTraversalLinkSpec {
  const RegionalCampaignTraversalLinkSpec({
    required this.fromSurfaceId,
    required this.toSurfaceId,
    required this.segment,
  });

  final String fromSurfaceId;
  final String toSurfaceId;
  final TraversalSegment segment;
}

/// A fully typed regional mechanic. Fields that do not apply to [kind] remain
/// null and are rejected if the required fields for that kind are missing.
final class RegionalCampaignFeatureSpec {
  const RegionalCampaignFeatureSpec({
    required this.id,
    required this.kind,
    required this.position,
    required this.size,
    this.end,
    this.timeline = const <RegionalCampaignPointSpec>[],
    this.sourceId,
    this.periodSeconds,
    this.activeSeconds,
    this.inactiveSeconds,
    this.phaseOffset = 0,
    this.direction,
    this.breakDelay,
    this.restoreDelay,
  });

  final String id;
  final RegionalCampaignFeatureKind kind;
  final RegionalCampaignPointSpec position;
  final RegionalCampaignPointSpec size;
  final RegionalCampaignPointSpec? end;
  final List<RegionalCampaignPointSpec> timeline;
  final String? sourceId;
  final double? periodSeconds;
  final double? activeSeconds;
  final double? inactiveSeconds;
  final double phaseOffset;
  final double? direction;
  final double? breakDelay;
  final double? restoreDelay;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  bool get isDynamicSurface => switch (kind) {
    RegionalCampaignFeatureKind.movingPlatform ||
    RegionalCampaignFeatureKind.rewindPlatform ||
    RegionalCampaignFeatureKind.mergingPlatform ||
    RegionalCampaignFeatureKind.conveyorPlatform ||
    RegionalCampaignFeatureKind.breakablePlatform => true,
    _ => false,
  };
}

final class RegionalCampaignTerrainPulseSpec {
  const RegionalCampaignTerrainPulseSpec({
    required this.routeId,
    required this.bridgeBounds,
    required this.nodePosition,
  });

  final String routeId;
  final Rect bridgeBounds;
  final RegionalCampaignPointSpec nodePosition;
}

/// Immutable runtime representation of one ROOM 2/3 campaign scene.
///
/// Rendering, collision, enemies, interaction sockets, objective nodes and
/// traversal validation all consume this object. This removes the previous
/// split-brain state where backdrop art and controller Rect constants could
/// silently diverge.
final class RegionalCampaignRoomLayout {
  const RegionalCampaignRoomLayout({
    required this.nodeId,
    required this.region,
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
    required this.objectiveNodes,
    required this.terrainPulse,
  });

  final CampaignNodeId nodeId;
  final CampaignRegion region;
  final double width;
  final double height;
  final double killPlaneY;
  final bool isBackdropAligned;
  final String? environmentAsset;
  final RegionalCampaignCameraSpec camera;
  final RegionalCampaignPointSpec westSpawn;
  final RegionalCampaignPointSpec eastSpawn;
  final Map<String, RegionalCampaignPointSpec> anchors;
  final List<RegionalCampaignSurfaceSpec> surfaces;
  final List<RegionalCampaignTraversalLinkSpec> traversalLinks;
  final List<RegionalCampaignEnemySpawnSpec> enemies;
  final CampaignEncounterSpec? encounter;
  final List<RegionalCampaignFeatureSpec> features;
  final List<RegionalCampaignPointSpec> objectiveNodes;
  final RegionalCampaignTerrainPulseSpec? terrainPulse;

  Vector2 get size => Vector2(width, height);

  RegionalCampaignPointSpec spawnFor(CampaignNodeEntry entry) =>
      entry == CampaignNodeEntry.west ? westSpawn : eastSpawn;

  RegionalCampaignPointSpec? anchor(String id) => anchors[id];

  RegionalCampaignPointSpec requireAnchor(String id) {
    final point = anchors[id];
    if (point == null) {
      throw StateError('${nodeId.name} is missing required anchor "$id".');
    }
    return point;
  }

  List<TraversalSegment> get requiredTraversalSegments =>
      traversalLinks.map((link) => link.segment).toList(growable: false);
}

final class RegionalCampaignRoomLayoutCatalog {
  RegionalCampaignRoomLayoutCatalog._(this._rooms);

  static const String temporalHallAssetPath =
      'assets/tiles/maps/temporal_hall_runtime_v1.json';
  static const String collisionArchiveAssetPath =
      'assets/tiles/maps/collision_archive_runtime_v1.json';

  final Map<CampaignNodeId, RegionalCampaignRoomLayout> _rooms;

  Iterable<RegionalCampaignRoomLayout> get rooms => _rooms.values;

  RegionalCampaignRoomLayout room(CampaignNodeId nodeId) {
    final layout = _rooms[nodeId];
    if (layout == null) {
      throw StateError('No regional runtime layout for ${nodeId.name}.');
    }
    return layout;
  }

  static Future<RegionalCampaignRoomLayoutCatalog> load({
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    final sources = await Future.wait(<Future<String>>[
      assets.loadString(temporalHallAssetPath),
      assets.loadString(collisionArchiveAssetPath),
    ]);
    return fromJsonSources(
      temporalHallSource: sources[0],
      collisionArchiveSource: sources[1],
    );
  }

  static RegionalCampaignRoomLayoutCatalog fromJsonSources({
    required String temporalHallSource,
    required String collisionArchiveSource,
  }) {
    final rooms = <CampaignNodeId, RegionalCampaignRoomLayout>{};
    _parseRegionSource(
      temporalHallSource,
      expectedRegion: CampaignRegion.temporalHall,
      sourceLabel: temporalHallAssetPath,
      target: rooms,
    );
    _parseRegionSource(
      collisionArchiveSource,
      expectedRegion: CampaignRegion.collisionArchive,
      sourceLabel: collisionArchiveAssetPath,
      target: rooms,
    );
    final catalog = RegionalCampaignRoomLayoutCatalog._(
      Map<CampaignNodeId, RegionalCampaignRoomLayout>.unmodifiable(rooms),
    );
    RegionalCampaignRoomLayoutValidator.validate(catalog);
    return catalog;
  }

  static void _parseRegionSource(
    String source, {
    required CampaignRegion expectedRegion,
    required String sourceLabel,
    required Map<CampaignNodeId, RegionalCampaignRoomLayout> target,
  }) {
    final root = _requireMap(jsonDecode(source), '$sourceLabel.root');
    _rejectUnknownKeys(root, const <String>{
      'schemaVersion',
      'region',
      'rooms',
    }, '$sourceLabel.root');
    final schemaVersion = _requireInt(root, 'schemaVersion', sourceLabel);
    if (schemaVersion != 1) {
      throw FormatException(
        '$sourceLabel has unsupported schema $schemaVersion; expected 1.',
      );
    }
    final region = _enumByName(
      CampaignRegion.values,
      _requireString(root, 'region', sourceLabel),
      '$sourceLabel.region',
    );
    if (region != expectedRegion) {
      throw FormatException(
        '$sourceLabel declares ${region.name}; expected ${expectedRegion.name}.',
      );
    }
    final roomValues = _requireList(root, 'rooms', sourceLabel);
    for (var index = 0; index < roomValues.length; index += 1) {
      final path = '$sourceLabel.rooms[$index]';
      final layout = _parseRoom(
        _requireMap(roomValues[index], path),
        path,
        region,
      );
      if (target.containsKey(layout.nodeId)) {
        throw FormatException('$path duplicates node ${layout.nodeId.name}.');
      }
      target[layout.nodeId] = layout;
    }
  }

  static RegionalCampaignRoomLayout _parseRoom(
    Map<String, Object?> map,
    String path,
    CampaignRegion region,
  ) {
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
      'objectiveNodes',
      'terrainPulse',
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
    final anchors = <String, RegionalCampaignPointSpec>{};
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
          return RegionalCampaignSurfaceSpec(
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
    final surfacesById = <String, RegionalCampaignSurfaceSpec>{
      for (final surface in surfaces) surface.id: surface,
    };

    final traversal = _requireList(map, 'traversal', path).indexed
        .map((entry) {
          final linkPath = '$path.traversal[${entry.$1}]';
          final link = _requireMap(entry.$2, linkPath);
          _rejectUnknownKeys(link, const <String>{
            'id',
            'fromSurfaceId',
            'toSurfaceId',
            'requiredForCompletion',
            'requirement',
            'requiresMovingPlatform',
            'requiresBreakablePlatform',
          }, linkPath);
          final fromId = _requireString(link, 'fromSurfaceId', linkPath);
          final toId = _requireString(link, 'toSurfaceId', linkPath);
          final from = surfacesById[fromId];
          final to = surfacesById[toId];
          if (from == null || to == null) {
            throw FormatException(
              '$linkPath references missing surface ${from == null ? fromId : toId}.',
            );
          }
          return RegionalCampaignTraversalLinkSpec(
            fromSurfaceId: fromId,
            toSurfaceId: toId,
            segment: TraversalSegment(
              id: _requireString(link, 'id', linkPath),
              rise: (from.bounds.top - to.bounds.top).abs(),
              gap: _horizontalGap(from.bounds, to.bounds),
              landingWidth: to.bounds.width,
              requiredForCompletion: _optionalBool(
                link,
                'requiredForCompletion',
                true,
                linkPath,
              ),
              requirement: _enumByName(
                TraversalAbilityRequirement.values,
                _optionalString(
                  link,
                  'requirement',
                  TraversalAbilityRequirement.universal.name,
                  linkPath,
                ),
                '$linkPath.requirement',
              ),
              requiresMovingPlatform: _optionalBool(
                link,
                'requiresMovingPlatform',
                false,
                linkPath,
              ),
              requiresBreakablePlatform: _optionalBool(
                link,
                'requiresBreakablePlatform',
                false,
                linkPath,
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
          return RegionalCampaignEnemySpawnSpec(
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
            'end',
            'timeline',
            'sourceId',
            'periodSeconds',
            'activeSeconds',
            'inactiveSeconds',
            'phaseOffset',
            'direction',
            'breakDelay',
            'restoreDelay',
          }, featurePath);
          final sourceId = feature['sourceId'];
          if (sourceId != null && sourceId is! String) {
            throw FormatException('$featurePath.sourceId must be a String.');
          }
          final timeline = feature.containsKey('timeline')
              ? _requireList(feature, 'timeline', featurePath).indexed
                    .map(
                      (point) => _parsePoint(
                        point.$2,
                        '$featurePath.timeline[${point.$1}]',
                      ),
                    )
                    .toList(growable: false)
              : const <RegionalCampaignPointSpec>[];
          return RegionalCampaignFeatureSpec(
            id: _requireString(feature, 'id', featurePath),
            kind: _enumByName(
              RegionalCampaignFeatureKind.values,
              _requireString(feature, 'kind', featurePath),
              '$featurePath.kind',
            ),
            position: _parsePoint(
              _requireValue(feature, 'position', featurePath),
              '$featurePath.position',
            ),
            size: feature.containsKey('size')
                ? _parsePoint(feature['size'], '$featurePath.size')
                : const RegionalCampaignPointSpec(0, 0),
            end: feature.containsKey('end')
                ? _parsePoint(feature['end'], '$featurePath.end')
                : null,
            timeline: timeline,
            sourceId: sourceId as String?,
            periodSeconds: _optionalDouble(
              feature,
              'periodSeconds',
              featurePath,
            ),
            activeSeconds: _optionalDouble(
              feature,
              'activeSeconds',
              featurePath,
            ),
            inactiveSeconds: _optionalDouble(
              feature,
              'inactiveSeconds',
              featurePath,
            ),
            phaseOffset:
                _optionalDouble(feature, 'phaseOffset', featurePath) ?? 0,
            direction: _optionalDouble(feature, 'direction', featurePath),
            breakDelay: _optionalDouble(feature, 'breakDelay', featurePath),
            restoreDelay: _optionalDouble(feature, 'restoreDelay', featurePath),
          );
        })
        .toList(growable: false);

    final objectiveNodes = _requireList(map, 'objectiveNodes', path).indexed
        .map(
          (entry) => _parsePoint(entry.$2, '$path.objectiveNodes[${entry.$1}]'),
        )
        .toList(growable: false);

    RegionalCampaignTerrainPulseSpec? terrainPulse;
    if (map['terrainPulse'] != null) {
      final pulsePath = '$path.terrainPulse';
      final pulse = _requireMap(map['terrainPulse'], pulsePath);
      _rejectUnknownKeys(pulse, const <String>{
        'routeId',
        'bridge',
        'node',
      }, pulsePath);
      terrainPulse = RegionalCampaignTerrainPulseSpec(
        routeId: _requireString(pulse, 'routeId', pulsePath),
        bridgeBounds: _parseRect(
          _requireValue(pulse, 'bridge', pulsePath),
          '$pulsePath.bridge',
        ),
        nodePosition: _parsePoint(
          _requireValue(pulse, 'node', pulsePath),
          '$pulsePath.node',
        ),
      );
    }

    final backdrop = map['environmentAsset'];
    if (backdrop != null && backdrop is! String) {
      throw FormatException('$path.environmentAsset must be a String.');
    }
    return RegionalCampaignRoomLayout(
      nodeId: nodeId,
      region: region,
      width: size.x,
      height: size.y,
      killPlaneY: _requireDouble(map, 'killPlaneY', path),
      isBackdropAligned: _requireBool(map, 'backdropAligned', path),
      environmentAsset: backdrop as String?,
      camera: RegionalCampaignCameraSpec(
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
      anchors: Map<String, RegionalCampaignPointSpec>.unmodifiable(anchors),
      surfaces: List<RegionalCampaignSurfaceSpec>.unmodifiable(surfaces),
      traversalLinks: List<RegionalCampaignTraversalLinkSpec>.unmodifiable(
        traversal,
      ),
      enemies: List<RegionalCampaignEnemySpawnSpec>.unmodifiable(enemies),
      encounter: encounter,
      features: List<RegionalCampaignFeatureSpec>.unmodifiable(features),
      objectiveNodes: List<RegionalCampaignPointSpec>.unmodifiable(
        objectiveNodes,
      ),
      terrainPulse: terrainPulse,
    );
  }

  static RegionalCampaignPointSpec _parsePoint(Object? value, String path) {
    if (value is! List || value.length != 2 || value.any((v) => v is! num)) {
      throw FormatException('$path must be a two-number array.');
    }
    return RegionalCampaignPointSpec(
      (value[0] as num).toDouble(),
      (value[1] as num).toDouble(),
    );
  }

  static Rect _parseRect(Object? value, String path) {
    if (value is! List || value.length != 4 || value.any((v) => v is! num)) {
      throw FormatException('$path must be a four-number array.');
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
  ) => map.containsKey(key) ? _requireString(map, key, path) : fallback;

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

  static double? _optionalDouble(
    Map<String, Object?> map,
    String key,
    String path,
  ) => map.containsKey(key) ? _requireDouble(map, key, path) : null;

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
  ) => map.containsKey(key) ? _requireBool(map, key, path) : fallback;

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

abstract final class RegionalCampaignRoomLayoutValidator {
  static const Set<CampaignNodeId> requiredNodes = <CampaignNodeId>{
    CampaignNodeId.temporalAscent,
    CampaignNodeId.temporalFracture,
    CampaignNodeId.temporalPendulum,
    CampaignNodeId.chronoJailer,
    CampaignNodeId.collisionCompression,
    CampaignNodeId.collisionFracture,
    CampaignNodeId.collisionMerge,
    CampaignNodeId.kernelChimera,
  };

  static const Set<CampaignNodeId> bossNodes = <CampaignNodeId>{
    CampaignNodeId.chronoJailer,
    CampaignNodeId.kernelChimera,
  };

  static void validate(RegionalCampaignRoomLayoutCatalog catalog) {
    final errors = <String>[];
    final actual = catalog.rooms.map((room) => room.nodeId).toSet();
    if (actual.length != requiredNodes.length ||
        !actual.containsAll(requiredNodes)) {
      errors.add(
        'rooms must be exactly ${requiredNodes.map((node) => node.name).join(', ')}',
      );
    }
    for (final room in catalog.rooms) {
      _validateRoom(room, errors);
    }
    if (errors.isNotEmpty) {
      throw FormatException(
        'Invalid regional campaign runtime maps:\n- ${errors.join('\n- ')}',
      );
    }
  }

  static void _validateRoom(
    RegionalCampaignRoomLayout room,
    List<String> errors,
  ) {
    final prefix = room.nodeId.name;
    final isBoss = bossNodes.contains(room.nodeId);
    final expectedRegion = switch (room.nodeId) {
      CampaignNodeId.temporalAscent ||
      CampaignNodeId.temporalFracture ||
      CampaignNodeId.temporalPendulum ||
      CampaignNodeId.chronoJailer => CampaignRegion.temporalHall,
      _ => CampaignRegion.collisionArchive,
    };
    if (room.region != expectedRegion) {
      errors.add(
        '$prefix belongs to ${expectedRegion.name}, not ${room.region.name}',
      );
    }
    if (room.width <= 0 || room.height <= 0) {
      errors.add('$prefix has a non-positive room size');
    }
    if (room.killPlaneY <= room.height) {
      errors.add('$prefix kill plane must be below the room');
    }
    if (room.camera.zoom <= 0 || room.camera.followResponsiveness <= 0) {
      errors.add('$prefix camera zoom/responsiveness must be positive');
    }
    if (room.camera.horizontalLead < 0 ||
        room.camera.horizontalDeadZone < 0 ||
        room.camera.verticalDeadZone < 0) {
      errors.add('$prefix camera lead/dead zones must not be negative');
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
      if (!ids.add(id)) errors.add('$prefix duplicates $kind id "$id"');
    }

    for (final surface in room.surfaces) {
      addId(surface.id, 'object');
      if (surface.bounds.width <= 0 || surface.bounds.height <= 0) {
        errors.add('$prefix surface ${surface.id} has non-positive size');
      }
      if (!_containsRect(room, surface.bounds)) {
        errors.add('$prefix surface ${surface.id} is outside the room');
      }
      if (room.isBackdropAligned &&
          !surface.isBoundary &&
          surface.renderArtwork) {
        errors.add('$prefix surface ${surface.id} duplicates backdrop art');
      }
    }
    for (final link in room.traversalLinks) {
      addId(link.segment.id, 'object');
    }
    for (final enemy in room.enemies) {
      addId(enemy.id, 'object');
      if (!_containsPoint(room, enemy.position)) {
        errors.add('$prefix enemy ${enemy.id} is outside the room');
      }
    }

    final sourceIds = <String>{};
    for (final feature in room.features) {
      addId(feature.id, 'object');
      _validateFeature(room, feature, errors);
      final sourceId = feature.sourceId;
      if (sourceId != null && !sourceIds.add(sourceId)) {
        errors.add('$prefix duplicates hazard sourceId "$sourceId"');
      }
    }
    for (final point in <RegionalCampaignPointSpec>[
      room.westSpawn,
      room.eastSpawn,
      ...room.anchors.values,
      ...room.objectiveNodes,
    ]) {
      if (!_containsPoint(room, point)) {
        errors.add('$prefix contains an out-of-bounds spawn/anchor/objective');
      }
    }
    for (final spawn in <RegionalCampaignPointSpec>[
      room.westSpawn,
      room.eastSpawn,
    ]) {
      if (!_hasSupport(room, spawn, verticalOffset: 36)) {
        errors.add('$prefix player spawn has no authored landing');
      }
    }

    final requiredAnchors = <String>{
      RegionalCampaignAnchorId.backDoor,
      if (!isBoss) ...<String>{
        RegionalCampaignAnchorId.forwardDoor,
        RegionalCampaignAnchorId.qaRecord,
      },
      if (_isFirstRoom(room.nodeId)) ...<String>{
        RegionalCampaignAnchorId.checkpoint,
        RegionalCampaignAnchorId.repairStation,
        RegionalCampaignAnchorId.hubShortcutDoor,
      },
      if (_isSecondRoom(room.nodeId)) RegionalCampaignAnchorId.secretDoor,
      if (_isThirdRoom(room.nodeId)) ...<String>{
        RegionalCampaignAnchorId.loadoutEvent,
        RegionalCampaignAnchorId.questReward,
      },
      if (isBoss) ...<String>{
        RegionalCampaignAnchorId.bossSpawn,
        RegionalCampaignAnchorId.bossReward,
        RegionalCampaignAnchorId.exitTerminal,
        RegionalCampaignAnchorId.hubLift,
      },
      if (room.nodeId == CampaignNodeId.chronoJailer)
        RegionalCampaignAnchorId.regionBranchDoor,
    };
    for (final id in requiredAnchors) {
      if (room.anchor(id) == null) errors.add('$prefix is missing anchor $id');
    }

    for (final id in <String>[
      RegionalCampaignAnchorId.backDoor,
      RegionalCampaignAnchorId.forwardDoor,
      RegionalCampaignAnchorId.checkpoint,
      RegionalCampaignAnchorId.repairStation,
      RegionalCampaignAnchorId.loadoutEvent,
      RegionalCampaignAnchorId.hubShortcutDoor,
      RegionalCampaignAnchorId.secretDoor,
      RegionalCampaignAnchorId.regionBranchDoor,
      RegionalCampaignAnchorId.hubLift,
    ]) {
      final anchor = room.anchor(id);
      if (anchor != null && !_hasSupport(room, anchor)) {
        errors.add('$prefix anchor $id has no authored landing');
      }
    }
    for (final service in <(String, double)>[
      (RegionalCampaignAnchorId.checkpoint, 46),
      (RegionalCampaignAnchorId.repairStation, 44),
      (RegionalCampaignAnchorId.loadoutEvent, 47),
    ]) {
      final anchor = room.anchor(service.$1);
      if (anchor != null &&
          !_hasFootprintSupport(room, anchor, halfWidth: service.$2)) {
        errors.add('$prefix anchor ${service.$1} overhangs its landing');
      }
    }
    for (final id in <String>[
      RegionalCampaignAnchorId.qaRecord,
      RegionalCampaignAnchorId.questReward,
      RegionalCampaignAnchorId.bossReward,
      RegionalCampaignAnchorId.exitTerminal,
    ]) {
      final anchor = room.anchor(id);
      if (anchor != null &&
          !_hasSupportAtAnyOffset(room, anchor, const <double>[0, 6])) {
        errors.add('$prefix anchor $id has no authored landing');
      }
    }
    final bossSpawn = room.anchor(RegionalCampaignAnchorId.bossSpawn);
    if (bossSpawn != null &&
        !_hasSupport(room, bossSpawn, verticalOffset: 56)) {
      errors.add('$prefix bossSpawn has no authored landing');
    }

    if (isBoss) {
      if (room.encounter != null) {
        errors.add('$prefix boss room encounter must be null');
      }
      if (room.enemies.isNotEmpty || room.objectiveNodes.isNotEmpty) {
        errors.add(
          '$prefix boss room must not author normal enemies/objectives',
        );
      }
      if (room.features
              .where(
                (feature) =>
                    feature.kind == RegionalCampaignFeatureKind.bossSeal,
              )
              .length !=
          2) {
        errors.add('$prefix requires exactly two boss seals');
      }
      if (room.features.any(
        (feature) => feature.kind != RegionalCampaignFeatureKind.bossSeal,
      )) {
        errors.add('$prefix boss room may only author boss seals');
      }
    } else {
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
      if (room.enemies.length != 4) {
        errors.add('$prefix requires exactly four normal enemies');
      }
      final objectiveSpec = RegionalRoomObjectiveCatalog.forNode(room.nodeId);
      final expectedObjectiveCount = objectiveSpec.requiredNodeCount;
      if (room.objectiveNodes.length != expectedObjectiveCount) {
        errors.add('$prefix requires $expectedObjectiveCount objective nodes');
      }
      for (var index = 0; index < room.objectiveNodes.length; index += 1) {
        final objective = room.objectiveNodes[index];
        if (!_hasSupport(room, objective)) {
          errors.add('$prefix objective $index has no authored landing');
        } else if (!_hasRequiredRoute(
          room,
          start: room.westSpawn,
          startOffset: 36,
          destination: objective,
        )) {
          errors.add('$prefix objective $index is outside the required route');
        }
      }
      final expectedOrder = List<int>.generate(
        expectedObjectiveCount,
        (i) => i,
      );
      final actualOrder = objectiveSpec.activationOrder.toList()..sort();
      if (!_sameInts(actualOrder, expectedOrder)) {
        errors.add('$prefix objective activationOrder is not a permutation');
      }
      final disabledSourceId = objectiveSpec.disabledHazardSourceId;
      if (disabledSourceId != null) {
        final matches = room.features
            .where((feature) => feature.sourceId == disabledSourceId)
            .toList(growable: false);
        if (matches.length != 1) {
          errors.add(
            '$prefix objective source $disabledSourceId must match one feature',
          );
        } else if (objectiveSpec.completionWindow ==
                RegionalRoomObjectiveCompletionWindow.hazardInactive &&
            matches.single.kind != RegionalCampaignFeatureKind.pulsingLaser) {
          errors.add('$prefix hazardInactive window must reference a laser');
        }
      }
      if (objectiveSpec.completionWindow ==
              RegionalRoomObjectiveCompletionWindow.platformMerged &&
          room.features
                  .where(
                    (feature) =>
                        feature.kind ==
                        RegionalCampaignFeatureKind.mergingPlatform,
                  )
                  .length !=
              1) {
        errors.add('$prefix platformMerged window requires one merge platform');
      }
      _validateObjectiveInteractionClearance(room, errors);
      _validateServiceDoorClearance(room, errors);
    }

    if (_isSecondRoom(room.nodeId)) {
      final pulse = room.terrainPulse;
      if (pulse == null) {
        errors.add('$prefix requires a terrain pulse route');
      } else {
        if (pulse.routeId.isEmpty || !_containsRect(room, pulse.bridgeBounds)) {
          errors.add('$prefix has an invalid terrain pulse bridge');
        }
        if (!_containsPoint(room, pulse.nodePosition) ||
            !_hasSupport(room, pulse.nodePosition)) {
          errors.add('$prefix terrain pulse node has no authored landing');
        }
        final nodeBounds = Rect.fromLTWH(
          pulse.nodePosition.x - 37,
          pulse.nodePosition.y - 70,
          74,
          70,
        );
        if (room.features.any(
          (feature) =>
              feature.kind == RegionalCampaignFeatureKind.spikeHazard &&
              feature.bounds.overlaps(nodeBounds),
        )) {
          errors.add('$prefix terrain pulse node overlaps a spike hazard');
        }
      }
    } else if (room.terrainPulse != null) {
      errors.add('$prefix must not author a terrain pulse route');
    }

    for (final weapon in PlayerWeapon.values) {
      for (final violation in PlatformerTraversalContract.validateRequiredRoute(
        room.requiredTraversalSegments,
        weapon: weapon,
      )) {
        errors.add('$prefix/${weapon.name}: $violation');
      }
    }
    final backDoor = room.anchor(RegionalCampaignAnchorId.backDoor);
    final forwardDoor = room.anchor(RegionalCampaignAnchorId.forwardDoor);
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
  }

  static void _validateFeature(
    RegionalCampaignRoomLayout room,
    RegionalCampaignFeatureSpec feature,
    List<String> errors,
  ) {
    final prefix = '${room.nodeId.name}/${feature.id}';
    if (!_containsPoint(room, feature.position)) {
      errors.add('$prefix starts outside the room');
    }
    if (feature.size.x <= 0 || feature.size.y <= 0) {
      errors.add('$prefix requires positive size');
    } else if (!_containsRect(room, feature.bounds)) {
      errors.add('$prefix exceeds room bounds');
    }
    bool positive(double? value) => value != null && value > 0;
    switch (feature.kind) {
      case RegionalCampaignFeatureKind.movingPlatform:
        if (feature.end == null || !positive(feature.periodSeconds)) {
          errors.add('$prefix requires end and positive periodSeconds');
        }
      case RegionalCampaignFeatureKind.rewindPlatform:
        if (feature.timeline.length < 2 || !positive(feature.periodSeconds)) {
          errors.add('$prefix requires 2+ timeline points and periodSeconds');
        } else if (feature.position.x != feature.timeline.first.x ||
            feature.position.y != feature.timeline.first.y) {
          errors.add('$prefix position must equal the first timeline point');
        }
      case RegionalCampaignFeatureKind.mergingPlatform:
        if (!positive(feature.periodSeconds)) {
          errors.add('$prefix requires positive periodSeconds');
        }
      case RegionalCampaignFeatureKind.conveyorPlatform:
        if (feature.direction == null || feature.direction == 0) {
          errors.add('$prefix requires non-zero direction');
        }
      case RegionalCampaignFeatureKind.breakablePlatform:
        if (!positive(feature.breakDelay) || !positive(feature.restoreDelay)) {
          errors.add('$prefix requires positive break/restore delay');
        }
      case RegionalCampaignFeatureKind.jumpPad:
        break;
      case RegionalCampaignFeatureKind.pulsingLaser:
        if (feature.sourceId == null ||
            !positive(feature.activeSeconds) ||
            !positive(feature.inactiveSeconds)) {
          errors.add('$prefix requires sourceId and active/inactive timing');
        }
      case RegionalCampaignFeatureKind.crusherHazard:
        if (feature.sourceId == null ||
            feature.end == null ||
            !positive(feature.periodSeconds)) {
          errors.add('$prefix requires sourceId, end and periodSeconds');
        }
      case RegionalCampaignFeatureKind.spikeHazard:
        if (feature.sourceId == null) errors.add('$prefix requires sourceId');
      case RegionalCampaignFeatureKind.bossSeal:
        break;
    }
    final end = feature.end;
    if (end != null &&
        !_containsRect(
          room,
          Rect.fromLTWH(end.x, end.y, feature.size.x, feature.size.y),
        )) {
      errors.add('$prefix end bounds leave the room');
    }
    for (final point in feature.timeline) {
      if (!_containsRect(
        room,
        Rect.fromLTWH(point.x, point.y, feature.size.x, feature.size.y),
      )) {
        errors.add('$prefix timeline bounds leave the room');
      }
    }
  }

  static bool _isFirstRoom(CampaignNodeId nodeId) =>
      nodeId == CampaignNodeId.temporalAscent ||
      nodeId == CampaignNodeId.collisionCompression;

  static bool _isSecondRoom(CampaignNodeId nodeId) =>
      nodeId == CampaignNodeId.temporalFracture ||
      nodeId == CampaignNodeId.collisionFracture;

  static bool _isThirdRoom(CampaignNodeId nodeId) =>
      nodeId == CampaignNodeId.temporalPendulum ||
      nodeId == CampaignNodeId.collisionMerge;

  static void _validateObjectiveInteractionClearance(
    RegionalCampaignRoomLayout room,
    List<String> errors,
  ) {
    final interceptors = <(String, RegionalCampaignPointSpec, double)>[
      for (final entry in <(String, double)>[
        (RegionalCampaignAnchorId.checkpoint, 86),
        (RegionalCampaignAnchorId.repairStation, 92),
        (RegionalCampaignAnchorId.loadoutEvent, 94),
      ])
        if (room.anchor(entry.$1) case final point?)
          (entry.$1, point, entry.$2),
      if (room.terrainPulse case final pulse?)
        ('terrainPulse', pulse.nodePosition, 88),
    ];
    for (var index = 0; index < room.objectiveNodes.length; index += 1) {
      final objective = room.objectiveNodes[index];
      for (final interceptor in interceptors) {
        final dx = objective.x - interceptor.$2.x;
        final dy = objective.y - interceptor.$2.y;
        if (dx * dx + dy * dy <= interceptor.$3 * interceptor.$3) {
          errors.add(
            '${room.nodeId.name} objective $index overlaps '
            '${interceptor.$1} interaction radius',
          );
        }
      }
    }
  }

  static void _validateServiceDoorClearance(
    RegionalCampaignRoomLayout room,
    List<String> errors,
  ) {
    final interceptors = <(String, RegionalCampaignPointSpec, double)>[
      for (final entry in <(String, double)>[
        (RegionalCampaignAnchorId.checkpoint, 86),
        (RegionalCampaignAnchorId.repairStation, 92),
        (RegionalCampaignAnchorId.loadoutEvent, 94),
      ])
        if (room.anchor(entry.$1) case final point?)
          (entry.$1, point, entry.$2),
      if (room.terrainPulse case final pulse?)
        ('terrainPulse', pulse.nodePosition, 88),
    ];
    for (final doorId in <String>[
      RegionalCampaignAnchorId.backDoor,
      RegionalCampaignAnchorId.forwardDoor,
      RegionalCampaignAnchorId.hubShortcutDoor,
      RegionalCampaignAnchorId.secretDoor,
    ]) {
      final door = room.anchor(doorId);
      if (door == null) continue;
      final playerX = door.x;
      final playerY = door.y - 36;
      for (final interceptor in interceptors) {
        final dx = playerX - interceptor.$2.x;
        final dy = playerY - interceptor.$2.y;
        if (dx * dx + dy * dy <= interceptor.$3 * interceptor.$3) {
          errors.add(
            '${room.nodeId.name} $doorId is intercepted by '
            '${interceptor.$1}',
          );
        }
      }
    }
  }

  static bool _sameInts(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static bool _containsPoint(
    RegionalCampaignRoomLayout room,
    RegionalCampaignPointSpec point,
  ) =>
      point.x >= 0 &&
      point.y >= 0 &&
      point.x <= room.width &&
      point.y <= room.height;

  static bool _containsRect(RegionalCampaignRoomLayout room, Rect rect) =>
      rect.left >= 0 &&
      rect.top >= 0 &&
      rect.right <= room.width &&
      rect.bottom <= room.height;

  static bool _hasSupport(
    RegionalCampaignRoomLayout room,
    RegionalCampaignPointSpec point, {
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

  static bool _hasFootprintSupport(
    RegionalCampaignRoomLayout room,
    RegionalCampaignPointSpec point, {
    required double halfWidth,
  }) => room.surfaces.any(
    (surface) =>
        !surface.isBoundary &&
        point.x - halfWidth >= surface.bounds.left &&
        point.x + halfWidth <= surface.bounds.right &&
        (surface.bounds.top - point.y).abs() <= .01,
  );

  static bool _hasSupportAtAnyOffset(
    RegionalCampaignRoomLayout room,
    RegionalCampaignPointSpec point,
    Iterable<double> offsets,
  ) =>
      offsets.any((offset) => _hasSupport(room, point, verticalOffset: offset));

  static bool _hasRequiredRoute(
    RegionalCampaignRoomLayout room, {
    required RegionalCampaignPointSpec start,
    required double startOffset,
    required RegionalCampaignPointSpec destination,
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

  static Set<String> _supportSurfaceIds(
    RegionalCampaignRoomLayout room,
    RegionalCampaignPointSpec point, {
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
