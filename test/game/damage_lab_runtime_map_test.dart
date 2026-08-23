import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/rooms/maps/damage_lab_room_layout.dart';

void main() {
  late String source;

  setUpAll(() async {
    source = await File(DamageLabRoomLayoutCatalog.assetPath).readAsString();
  });

  test('runtime map owns all four Damage Lab rooms and their assets', () {
    final catalog = DamageLabRoomLayoutCatalog.fromJson(source);

    expect(
      catalog.rooms.map((room) => room.nodeId).toSet(),
      DamageLabRoomLayoutValidator.requiredNodes,
    );
    for (final room in catalog.rooms.where(
      (candidate) => candidate.isBackdropAligned,
    )) {
      expect(File(room.environmentAsset!).existsSync(), isTrue);
      expect(room.width, 1920);
      expect(room.height, 1080);
      expect(room.surfaces, isNotEmpty);
    }
  });

  test('mandatory traversal metrics are derived from referenced surfaces', () {
    final catalog = DamageLabRoomLayoutCatalog.fromJson(source);
    final workshop = catalog.room(CampaignNodeId.damageWorkshop);
    final dip = workshop.traversalLinks.singleWhere(
      (link) => link.segment.id == 'damage.workshop.central-dip-a',
    );
    final airlock = workshop.traversalLinks.singleWhere(
      (link) => link.segment.id == 'damage.workshop.airlock-entry',
    );

    expect(dip.fromSurfaceId, 'workshop.route.west');
    expect(dip.toSurfaceId, 'workshop.route.dip-a');
    expect(dip.segment.rise, 35);
    expect(dip.segment.gap, 0);
    expect(dip.segment.landingWidth, 96);
    expect(airlock.segment.rise, 0);
    expect(airlock.segment.gap, 0);
    expect(airlock.segment.landingWidth, 740);
  });

  test(
    'weapon sockets store placement while the world graph owns topology',
    () {
      final catalog = DamageLabRoomLayoutCatalog.fromJson(source);
      final assembly = catalog.room(CampaignNodeId.damageAssembly);
      final graph = CampaignWorldGraph.standard();

      expect(assembly.secretDoors, hasLength(PlayerWeapon.values.length));
      for (final weapon in PlayerWeapon.values) {
        final requirement = switch (weapon) {
          PlayerWeapon.sword => CampaignRouteRequirement.swordDash,
          PlayerWeapon.gauntlet => CampaignRouteRequirement.gauntletDoubleJump,
          PlayerWeapon.gun => CampaignRouteRequirement.gunRangedSwitch,
        };
        expect(
          graph
              .connectionsFrom(CampaignNodeId.damageAssembly)
              .where((connection) => connection.requirement == requirement),
          hasLength(1),
        );
        expect(assembly.secretDoorFor(weapon).position.x, greaterThan(0));
      }
    },
  );

  test('validator rejects a disconnected mandatory surface graph', () {
    final decoded = _decodedSource(source);
    final workshop = _room(decoded, 'damageWorkshop');
    final traversal = workshop['traversal']! as List<dynamic>;
    final firstDip = traversal.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['id'] == 'damage.workshop.central-dip-a',
    );
    firstDip['toSurfaceId'] = 'workshop.route.west';

    expect(
      () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(decoded)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('cannot reach the forward door'),
        ),
      ),
    );
  });

  test(
    'validator rejects duplicate weapon sockets and out-of-bounds terrain',
    () {
      final duplicateSocket = _decodedSource(source);
      final assembly = _room(duplicateSocket, 'damageAssembly');
      final doors = assembly['secretDoors']! as List<dynamic>;
      (doors[1]! as Map<String, dynamic>)['weapon'] = 'sword';
      expect(
        () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(duplicateSocket)),
        throwsA(isA<FormatException>()),
      );

      final invalidSurface = _decodedSource(source);
      final overflow = _room(invalidSurface, 'damageOverflow');
      final surfaces = overflow['surfaces']! as List<dynamic>;
      (surfaces.first! as Map<String, dynamic>)['rect'] = <num>[
        -1,
        0,
        24,
        1080,
      ];
      expect(
        () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(invalidSurface)),
        throwsA(isA<FormatException>()),
      );
    },
  );
}

Map<String, dynamic> _decodedSource(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

Map<String, dynamic> _room(Map<String, dynamic> source, String node) =>
    (source['rooms']! as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((room) => room['node'] == node);
