import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/rooms/maps/regional_campaign_room_layout.dart';

void main() {
  late String temporalSource;
  late String collisionSource;

  setUpAll(() async {
    temporalSource = await File(
      RegionalCampaignRoomLayoutCatalog.temporalHallAssetPath,
    ).readAsString();
    collisionSource = await File(
      RegionalCampaignRoomLayoutCatalog.collisionArchiveAssetPath,
    ).readAsString();
  });

  RegionalCampaignRoomLayoutCatalog loadCatalog({
    String? temporal,
    String? collision,
  }) => RegionalCampaignRoomLayoutCatalog.fromJsonSources(
    temporalHallSource: temporal ?? temporalSource,
    collisionArchiveSource: collision ?? collisionSource,
  );

  test('ROOM 2 and ROOM 3 load as eight validated runtime maps', () {
    final catalog = loadCatalog();
    expect(
      catalog.rooms.map((room) => room.nodeId).toSet(),
      RegionalCampaignRoomLayoutValidator.requiredNodes,
    );

    for (final layout in catalog.rooms) {
      final isBoss = RegionalCampaignRoomLayoutValidator.bossNodes.contains(
        layout.nodeId,
      );
      expect(layout.surfaces, isNotEmpty, reason: layout.nodeId.name);
      expect(
        layout.requiredTraversalSegments,
        isNotEmpty,
        reason: layout.nodeId.name,
      );
      expect(layout.enemies.length, isBoss ? 0 : 4);
      expect(layout.objectiveNodes, isBoss ? isEmpty : isNotEmpty);
      final environmentAsset = layout.environmentAsset;
      if (environmentAsset != null) {
        expect(
          File(environmentAsset).existsSync(),
          isTrue,
          reason: '${layout.nodeId.name} backdrop asset is missing',
        );
      }
    }
  });

  test('every mandatory regional route is static and safe for all weapons', () {
    final catalog = loadCatalog();
    for (final layout in catalog.rooms) {
      for (final weapon in PlayerWeapon.values) {
        expect(
          PlatformerTraversalContract.validateRequiredRoute(
            layout.requiredTraversalSegments,
            weapon: weapon,
          ),
          isEmpty,
          reason: '${layout.nodeId.name}/${weapon.name}',
        );
      }
    }
  });

  test('corrected service sockets sit on authored surfaces', () {
    final catalog = loadCatalog();
    expect(
      catalog
          .room(CampaignNodeId.temporalAscent)
          .requireAnchor(RegionalCampaignAnchorId.repairStation)
          .toVector2()
          .toString(),
      '[510.0,825.0]',
    );
    expect(
      catalog
          .room(CampaignNodeId.temporalPendulum)
          .requireAnchor(RegionalCampaignAnchorId.loadoutEvent)
          .y,
      325,
    );
    expect(
      catalog
          .room(CampaignNodeId.collisionCompression)
          .requireAnchor(RegionalCampaignAnchorId.repairStation)
          .y,
      905,
    );
  });

  test('unknown keys fail loudly with their JSON path', () {
    final decoded = jsonDecode(temporalSource) as Map<String, dynamic>;
    decoded['silentTypo'] = true;
    expect(
      () => loadCatalog(temporal: jsonEncode(decoded)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('unknown key "silentTypo"'),
        ),
      ),
    );
  });

  test('missing traversal surface references are rejected', () {
    final decoded = jsonDecode(collisionSource) as Map<String, dynamic>;
    final rooms = decoded['rooms'] as List<dynamic>;
    final compression = rooms.first as Map<String, dynamic>;
    final traversal = compression['traversal'] as List<dynamic>;
    (traversal.first as Map<String, dynamic>)['toSurfaceId'] =
        'missing.surface';
    expect(
      () => loadCatalog(collision: jsonEncode(decoded)),
      throwsA(isA<FormatException>()),
    );
  });

  test('objective-to-hazard drift is rejected before the game mounts', () {
    final decoded = jsonDecode(collisionSource) as Map<String, dynamic>;
    final rooms = decoded['rooms'] as List<dynamic>;
    final merge = rooms.cast<Map<String, dynamic>>().singleWhere(
      (room) => room['node'] == CampaignNodeId.collisionMerge.name,
    );
    final features = merge['features'] as List<dynamic>;
    final fusionAxis = features.cast<Map<String, dynamic>>().singleWhere(
      (feature) => feature['id'] == 'merge.hazard.fusion-axis',
    );
    fusionAxis['sourceId'] = 'hazard.typo';
    expect(
      () => loadCatalog(collision: jsonEncode(decoded)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('objective source'),
        ),
      ),
    );
  });

  test('service terminals cannot steal an objective interaction', () {
    final decoded = jsonDecode(collisionSource) as Map<String, dynamic>;
    final rooms = decoded['rooms'] as List<dynamic>;
    final compression = rooms.cast<Map<String, dynamic>>().singleWhere(
      (room) => room['node'] == CampaignNodeId.collisionCompression.name,
    );
    final anchors = compression['anchors'] as Map<String, dynamic>;
    anchors[RegionalCampaignAnchorId.repairStation] = <num>[600, 830];
    expect(
      () => loadCatalog(collision: jsonEncode(decoded)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('overlaps repairStation interaction radius'),
        ),
      ),
    );
  });

  test('an unsupported objective cannot silently soft-lock a room', () {
    final decoded = jsonDecode(temporalSource) as Map<String, dynamic>;
    final rooms = decoded['rooms'] as List<dynamic>;
    final ascent = rooms.cast<Map<String, dynamic>>().singleWhere(
      (room) => room['node'] == CampaignNodeId.temporalAscent.name,
    );
    final objectiveNodes = ascent['objectiveNodes'] as List<dynamic>;
    objectiveNodes[0] = <num>[410, 824];
    expect(
      () => loadCatalog(temporal: jsonEncode(decoded)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('objective 0 has no authored landing'),
        ),
      ),
    );
  });

  test('dynamic feature paths include their full bounds in validation', () {
    final decoded = jsonDecode(collisionSource) as Map<String, dynamic>;
    final rooms = decoded['rooms'] as List<dynamic>;
    final compression = rooms.cast<Map<String, dynamic>>().singleWhere(
      (room) => room['node'] == CampaignNodeId.collisionCompression.name,
    );
    final features = compression['features'] as List<dynamic>;
    final mover = features.cast<Map<String, dynamic>>().firstWhere(
      (feature) => feature['kind'] == 'movingPlatform',
    );
    mover['end'] = <num>[1900, 430];
    expect(
      () => loadCatalog(collision: jsonEncode(decoded)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('end bounds leave the room'),
        ),
      ),
    );
  });

  test('boss maps cannot declare mechanics the controller would ignore', () {
    final decoded = jsonDecode(temporalSource) as Map<String, dynamic>;
    final rooms = decoded['rooms'] as List<dynamic>;
    final boss = rooms.cast<Map<String, dynamic>>().singleWhere(
      (room) => room['node'] == CampaignNodeId.chronoJailer.name,
    );
    final features = boss['features'] as List<dynamic>;
    features.add(<String, dynamic>{
      'id': 'chrono.ignored-jump-pad',
      'kind': 'jumpPad',
      'position': <num>[400, 472],
      'size': <num>[54, 12],
    });
    expect(
      () => loadCatalog(temporal: jsonEncode(decoded)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('boss room may only author boss seals'),
        ),
      ),
    );
  });
}
