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

  test('runtime map owns four rooms with visible collision geometry', () {
    final catalog = DamageLabRoomLayoutCatalog.fromJson(source);

    expect(
      catalog.rooms.map((room) => room.nodeId).toSet(),
      DamageLabRoomLayoutValidator.requiredNodes,
    );
    for (final room in catalog.rooms) {
      expect(room.isBackdropAligned, isFalse, reason: room.nodeId.name);
      expect(room.environmentAsset, isNull, reason: room.nodeId.name);
      expect(room.surfaces, isNotEmpty);
      expect(
        room.surfaces
            .where((surface) => !surface.isBoundary)
            .every((surface) => surface.renderArtwork),
        isTrue,
        reason: '${room.nodeId.name} must render every collidable surface',
      );
      expect(
        room.surfaces
            .where((surface) => surface.isBoundary)
            .every((surface) => !surface.renderArtwork),
        isTrue,
        reason: '${room.nodeId.name} boundary walls stay invisible',
      );
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

  test('exploration encounters partition every enemy into paced waves', () {
    final catalog = DamageLabRoomLayoutCatalog.fromJson(source);

    for (final room in catalog.rooms) {
      if (room.nodeId == CampaignNodeId.overflowWarden) {
        expect(room.encounter, isNull);
        continue;
      }
      final encounter = room.encounter!;
      expect(encounter.waves.length, greaterThanOrEqualTo(2));
      expect(encounter.maxActiveEnemies, inInclusiveRange(1, 3));
      expect(
        encounter.enemyIds,
        unorderedEquals(room.enemies.map((enemy) => enemy.id)),
        reason: room.nodeId.name,
      );
      expect(room.westSpawn.x, lessThan(encounter.triggerZone.left));
      expect(room.eastSpawn.x, greaterThan(encounter.triggerZone.right));
      expect(
        encounter.combatCamera.zone.left,
        lessThanOrEqualTo(encounter.triggerZone.left),
      );
      expect(
        encounter.combatCamera.zone.right,
        greaterThanOrEqualTo(encounter.triggerZone.right),
      );
    }
  });

  test('encounter parser rejects unknown keys and validator rejects drift', () {
    final unknownKey = _decodedSource(source);
    final workshop = _room(unknownKey, 'damageWorkshop');
    final encounter = workshop['encounter']! as Map<String, dynamic>;
    encounter['intermissionSecond'] = encounter.remove('intermissionSeconds');
    expect(
      () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(unknownKey)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('unknown key "intermissionSecond"'),
        ),
      ),
    );

    final duplicateEnemy = _decodedSource(source);
    final duplicateEncounter =
        _room(duplicateEnemy, 'damageWorkshop')['encounter']!
            as Map<String, dynamic>;
    final waves = duplicateEncounter['waves']! as List<dynamic>;
    final firstIds =
        (waves.first! as Map<String, dynamic>)['enemyIds']! as List<dynamic>;
    final secondIds =
        (waves.last! as Map<String, dynamic>)['enemyIds']! as List<dynamic>;
    secondIds[0] = firstIds[0];
    expect(
      () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(duplicateEnemy)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('more than once'), contains('omits enemies')),
        ),
      ),
    );

    final bossEncounter = _decodedSource(source);
    _room(bossEncounter, 'overflowWarden')['encounter'] = _room(
      bossEncounter,
      'damageWorkshop',
    )['encounter'];
    expect(
      () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(bossEncounter)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('boss room encounter must be null'),
        ),
      ),
    );
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
