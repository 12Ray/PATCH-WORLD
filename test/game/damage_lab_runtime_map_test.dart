import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/ordinary_jump_reachability.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
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

  test('sword ordinary movement reaches every mandatory Damage Lab anchor', () {
    final catalog = DamageLabRoomLayoutCatalog.fromJson(source);
    for (final room in catalog.rooms) {
      final surfaces = room.surfaces
          .where((surface) => !surface.isBoundary)
          .map(
            (surface) =>
                OrdinaryJumpSurface(id: surface.id, bounds: surface.bounds),
          )
          .toList(growable: false);
      final destinationIds = room.nodeId == CampaignNodeId.overflowWarden
          ? const <String>[
              DamageLabAnchorId.backDoor,
              DamageLabAnchorId.bossReward,
              DamageLabAnchorId.exitTerminal,
              DamageLabAnchorId.regionBranchDoor,
            ]
          : const <String>[
              DamageLabAnchorId.backDoor,
              DamageLabAnchorId.forwardDoor,
            ];
      final destinations = <OrdinaryJumpAnchor>[
        for (final id in destinationIds)
          OrdinaryJumpAnchor(
            id: id,
            feet: Offset(room.requireAnchor(id).x, room.requireAnchor(id).y),
            settleDistance: 8,
          ),
      ];

      for (final entry in <(String, DamageLabPointSpec)>[
        ('westSpawn', room.westSpawn),
        ('eastSpawn', room.eastSpawn),
      ]) {
        final result = OrdinaryJumpReachability.analyze(
          surfaces: surfaces,
          start: OrdinaryJumpAnchor(
            id: entry.$1,
            feet: Offset(entry.$2.x, entry.$2.y + 16),
            settleDistance: 64,
          ),
          requiredAnchors: destinations,
        );
        for (final destination in destinations) {
          expect(
            result.isAnchorReachable(destination.id),
            isTrue,
            reason:
                '${room.nodeId.name}/${entry.$1} must reach '
                '${destination.id} without dash, double jump, or unlocks. '
                'Reachable: ${result.reachableSurfaceIds.join(', ')}',
          );
          expect(result.surfacePathTo(destination.id), isNotEmpty);
        }
      }
    }
  });

  test(
    'Warden owns a two-level pressure hangar with a universal floor route',
    () {
      final catalog = DamageLabRoomLayoutCatalog.fromJson(source);
      final warden = catalog.room(CampaignNodeId.overflowWarden);
      final mechanic = warden.bossMechanic!;

      expect(warden.width, greaterThanOrEqualTo(1440));
      expect(warden.height, greaterThanOrEqualTo(832));
      expect(
        warden.surfaces.where((surface) => !surface.isBoundary),
        hasLength(greaterThanOrEqualTo(5)),
      );
      expect(mechanic.pressureVents, hasLength(greaterThanOrEqualTo(3)));
      expect(mechanic.phasePlatforms, hasLength(greaterThanOrEqualTo(2)));
      expect(mechanic.safeZones, hasLength(greaterThanOrEqualTo(2)));
      expect(mechanic.summonGates, hasLength(greaterThanOrEqualTo(2)));

      final floorRoute = warden.requiredTraversalSegments.singleWhere(
        (segment) => segment.id == 'damage.warden.universal-floor',
      );
      expect(floorRoute.rise, 0);
      expect(floorRoute.gap, 0);
      expect(floorRoute.requirement, TraversalAbilityRequirement.universal);
      for (final weapon in PlayerWeapon.values) {
        expect(
          PlatformerTraversalContract.validateRequiredRoute(
            warden.requiredTraversalSegments,
            weapon: weapon,
          ),
          isEmpty,
          reason: '${weapon.name} must clear the Warden by the ground route',
        );
      }

      for (final platform in mechanic.phasePlatforms) {
        expect(
          warden.surfaces.any(
            (surface) =>
                !surface.isBoundary && surface.bounds.overlaps(platform.bounds),
          ),
          isFalse,
          reason: '${platform.id} must not duplicate visible static collision',
        );
      }
    },
  );

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

  test('validator rejects a tall collision wall across an authored jump', () {
    final decoded = _decodedSource(source);
    final assembly = _room(decoded, 'damageAssembly');
    final surfaces = (assembly['surfaces']! as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final west = surfaces.singleWhere(
      (surface) => surface['id'] == 'assembly.route.west',
    );
    final ascent = surfaces.singleWhere(
      (surface) => surface['id'] == 'assembly.route.ascent-a',
    );
    west['rect'] = <num>[40, 565, 460, 30];
    ascent['rect'] = <num>[580, 490, 180, 24];
    surfaces.add(<String, dynamic>{
      'id': 'assembly.route.blocking-wall',
      'rect': <num>[520, 365, 24, 200],
      'renderArtwork': true,
    });

    expect(
      () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(decoded)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('damage.assembly.ascent-a'),
            contains('blocked for ordinary sword movement'),
          ),
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

  test('boss mechanic parser and validator reject authored contract drift', () {
    final unknownKey = _decodedSource(source);
    final mechanic =
        _room(unknownKey, 'overflowWarden')['bossMechanic']!
            as Map<String, dynamic>;
    mechanic['pressureValve'] = <dynamic>[];
    expect(
      () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(unknownKey)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('unknown key "pressureValve"'),
        ),
      ),
    );

    final missingVent = _decodedSource(source);
    final missingVentMechanic =
        _room(missingVent, 'overflowWarden')['bossMechanic']!
            as Map<String, dynamic>;
    final vents = missingVentMechanic['pressureVents']! as List<dynamic>;
    vents.removeLast();
    expect(
      () => DamageLabRoomLayoutCatalog.fromJson(jsonEncode(missingVent)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('requires at least three pressure vents'),
        ),
      ),
    );
  });
}

Map<String, dynamic> _decodedSource(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

Map<String, dynamic> _room(Map<String, dynamic> source, String node) =>
    (source['rooms']! as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((room) => room['node'] == node);
