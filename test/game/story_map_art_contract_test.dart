import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/story_map_art_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

void main() {
  group('story map art catalog', () {
    test('maps every existing campaign node exactly once', () {
      final ids = StoryMapArtCatalog.specs
          .map((spec) => spec.nodeId)
          .toList(growable: false);

      expect(StoryMapArtCatalog.specs, hasLength(23));
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate node id');
      expect(ids.toSet(), CampaignNodeId.values.toSet());
      expect(StoryMapArtCatalog.byNode.keys.toSet(), ids.toSet());

      for (final id in CampaignNodeId.values) {
        expect(StoryMapArtCatalog.specFor(id).nodeId, id);
      }
    });

    test('uses the complete grid-aligned three-layer contract', () {
      for (final spec in StoryMapArtCatalog.specs) {
        expect(spec.gridSize, 32, reason: spec.nodeId.name);
        expect(
          spec.recommendedSize.width % spec.gridSize,
          0,
          reason: '${spec.nodeId.name} width',
        );
        expect(
          spec.recommendedSize.height % spec.gridSize,
          0,
          reason: '${spec.nodeId.name} height',
        );
        expect(
          spec.layers,
          StoryMapArtCatalog.requiredLayers,
          reason: spec.nodeId.name,
        );
        expect(spec.displayNameKo.trim(), isNotEmpty);
        expect(spec.displayNameEn.trim(), isNotEmpty);
      }
    });

    test('keeps survival content outside the story map catalog', () {
      expect(
        StoryMapArtCatalog.specs.map((spec) => spec.nodeId.name),
        isNot(contains('survival')),
      );
      expect(
        StoryMapArtCatalog.specs.map(
          (spec) => spec.displayNameEn.toLowerCase(),
        ),
        everyElement(isNot(contains('survival'))),
      );
    });

    test('assigns exactly one optional secret per weapon in every region', () {
      final secrets = StoryMapArtCatalog.specs
          .where((spec) => spec.isWeaponSecret)
          .toList(growable: false);

      expect(secrets, hasLength(9));
      for (final secret in secrets) {
        expect(secret.mainPathUniversal, isFalse, reason: secret.nodeId.name);
      }
      for (final weapon in PlayerWeapon.values) {
        expect(
          secrets.where((spec) => spec.weaponSecret == weapon),
          hasLength(3),
          reason: weapon.name,
        );
      }

      expect(
        <CampaignNodeId, PlayerWeapon?>{
          for (final spec in secrets) spec.nodeId: spec.weaponSecret,
        },
        const <CampaignNodeId, PlayerWeapon>{
          CampaignNodeId.damageDashCache: PlayerWeapon.sword,
          CampaignNodeId.damageUpperArchive: PlayerWeapon.gauntlet,
          CampaignNodeId.damageTurretControl: PlayerWeapon.gun,
          CampaignNodeId.temporalDashRift: PlayerWeapon.sword,
          CampaignNodeId.temporalUpperLoop: PlayerWeapon.gauntlet,
          CampaignNodeId.temporalRelayControl: PlayerWeapon.gun,
          CampaignNodeId.collisionVectorCache: PlayerWeapon.sword,
          CampaignNodeId.collisionUpperMatrix: PlayerWeapon.gauntlet,
          CampaignNodeId.collisionPrismControl: PlayerWeapon.gun,
        },
      );
    });

    test('keeps hub, main rooms, bosses, and final route universal', () {
      final coreSpecs = StoryMapArtCatalog.specs.where(
        (spec) => !spec.isWeaponSecret,
      );

      expect(coreSpecs, hasLength(14));
      for (final spec in coreSpecs) {
        expect(spec.mainPathUniversal, isTrue, reason: spec.nodeId.name);
        expect(spec.weaponSecret, isNull, reason: spec.nodeId.name);
      }
    });

    test('all three weapons share every regional critical-path map', () {
      final graph = CampaignWorldGraph.standard();
      final paths = <List<CampaignNodeId>>[
        CampaignWorldGraph.damageMainPath,
        CampaignWorldGraph.temporalMainPath,
        CampaignWorldGraph.collisionMainPath,
      ];

      for (final weapon in PlayerWeapon.values) {
        for (final path in paths) {
          for (final nodeId in path) {
            expect(
              StoryMapArtCatalog.specFor(nodeId).mainPathUniversal,
              isTrue,
              reason: '${weapon.name} map access at ${nodeId.name}',
            );
          }
          for (var index = 0; index < path.length - 1; index += 1) {
            final connection = graph.connectionBetween(
              path[index],
              path[index + 1],
            );
            expect(
              connection.permits(
                weapon: weapon,
                unlockedShortcutIds: const <String>{},
                hasAllCoreSignatures: false,
              ),
              isTrue,
              reason:
                  '${weapon.name} blocked at ${path[index].name} -> '
                  '${path[index + 1].name}',
            );
          }
        }
      }
    });
  });
}
