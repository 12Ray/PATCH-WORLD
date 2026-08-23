import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_exploration_state.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

void main() {
  group('campaign world graph', () {
    test('defines fourteen core rooms and optional weapon routes', () {
      final graph = CampaignWorldGraph.standard();

      expect(graph.coreRoomCount, 14);
      expect(graph.nodes, contains(CampaignNodeId.bootSector));
      expect(graph.nodes, contains(CampaignNodeId.optimizerCore));

      const routeSources = <CampaignNodeId>{
        CampaignNodeId.damageAssembly,
        CampaignNodeId.temporalFracture,
        CampaignNodeId.collisionFracture,
      };
      for (final source in routeSources) {
        final optionalRequirements = graph.connections
            .where(
              (connection) =>
                  connection.from == source &&
                  graph.nodes[connection.to]!.kind == CampaignNodeKind.secret,
            )
            .map((connection) => connection.requirement)
            .toSet();
        expect(
          optionalRequirements,
          <CampaignRouteRequirement>{
            CampaignRouteRequirement.swordDash,
            CampaignRouteRequirement.gauntletDoubleJump,
            CampaignRouteRequirement.gunRangedSwitch,
          },
          reason: '$source must expose one route for every weapon',
        );
      }
      expect(
        graph.nodes.values.where(
          (node) => node.kind == CampaignNodeKind.secret,
        ),
        hasLength(9),
      );
    });

    test('every weapon can traverse all universal regional routes', () {
      final graph = CampaignWorldGraph.standard();
      final mainPaths = <List<CampaignNodeId>>[
        CampaignWorldGraph.damageMainPath,
        CampaignWorldGraph.temporalMainPath,
        CampaignWorldGraph.collisionMainPath,
      ];

      for (final weapon in PlayerWeapon.values) {
        for (final path in mainPaths) {
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
              reason: '${weapon.name} is blocked at ${path[index]}',
            );
          }
        }
      }
    });

    test('Damage Lab maintenance lift is locked until discovered', () {
      final graph = CampaignWorldGraph.standard();
      final state = CampaignExplorationState();
      final shortcut = graph.connectionBetween(
        CampaignNodeId.damageWorkshop,
        CampaignNodeId.damageOverflow,
      );

      expect(shortcut.requirement, CampaignRouteRequirement.unlockedShortcut);
      expect(state.canTraverse(shortcut, weapon: PlayerWeapon.sword), isFalse);
      state.unlockShortcut(CampaignWorldGraph.damageMaintenanceShortcutId);
      for (final weapon in PlayerWeapon.values) {
        expect(state.canTraverse(shortcut, weapon: weapon), isTrue);
      }
    });

    test('main chapter routes follow ROOM1(3 sub-quests) → ROOM2 → ROOM3', () {
      final graph = CampaignWorldGraph.standard();

      expect(CampaignWorldGraph.damageSubQuestPath, const <CampaignNodeId>[
        CampaignNodeId.damageWorkshop,
        CampaignNodeId.damageAssembly,
        CampaignNodeId.damageOverflow,
      ]);
      expect(CampaignWorldGraph.temporalSubQuestPath, const <CampaignNodeId>[
        CampaignNodeId.temporalAscent,
        CampaignNodeId.temporalFracture,
        CampaignNodeId.temporalPendulum,
      ]);
      expect(CampaignWorldGraph.collisionSubQuestPath, const <CampaignNodeId>[
        CampaignNodeId.collisionCompression,
        CampaignNodeId.collisionFracture,
        CampaignNodeId.collisionMerge,
      ]);
      expect(
        CampaignWorldGraph.damageMainPath.last,
        CampaignWorldGraph.damageLabBossNode,
      );
      expect(
        CampaignWorldGraph.temporalMainPath.last,
        CampaignWorldGraph.temporalBossNode,
      );
      expect(
        CampaignWorldGraph.collisionMainPath.last,
        CampaignWorldGraph.collisionBossNode,
      );

      final chapterChains = <List<CampaignNodeId>>[
        CampaignWorldGraph.damageMainPath,
        CampaignWorldGraph.temporalMainPath,
        CampaignWorldGraph.collisionMainPath,
      ];

      for (final chapter in chapterChains) {
        for (var index = 0; index < chapter.length - 1; index++) {
          final from = chapter[index];
          final to = chapter[index + 1];
          expect(
            CampaignWorldGraph.isLinearChapterTransition(from, to),
            isTrue,
            reason:
                'Expected ${from.name} -> ${to.name} to stay in linear room progression.',
          );
          expect(graph.connectionBetween(from, to), isNotNull);
        }
      }

      expect(
        CampaignWorldGraph.isLinearChapterTransition(
          CampaignNodeId.overflowWarden,
          CampaignNodeId.temporalAscent,
        ),
        isTrue,
        reason: 'ROOM1 boss should connect into ROOM2 entry.',
      );
      expect(
        CampaignWorldGraph.isLinearChapterTransition(
          CampaignNodeId.chronoJailer,
          CampaignNodeId.collisionCompression,
        ),
        isTrue,
        reason: 'ROOM2 boss should connect into ROOM3 entry.',
      );

      final collisionHubShortcut = graph.connectionBetween(
        CampaignNodeId.bootSector,
        CampaignNodeId.collisionCompression,
      );
      expect(
        collisionHubShortcut.requirement,
        CampaignRouteRequirement.unlockedShortcut,
      );
      expect(
        collisionHubShortcut.unlockId,
        CampaignWorldGraph.collisionHubAccessId,
      );
      expect(
        graph
            .connectionBetween(
              CampaignNodeId.chronoJailer,
              CampaignNodeId.collisionCompression,
            )
            .bidirectional,
        isTrue,
        reason: 'The linear first-clear route must still support backtracking.',
      );
      expect(
        () => graph.connectionBetween(
          CampaignNodeId.overflowWarden,
          CampaignNodeId.collisionCompression,
        ),
        throwsStateError,
        reason: 'ROOM3 must not be reachable before ROOM2 is cleared.',
      );
    });
  });

  group('campaign exploration state', () {
    test('records visits, reveals neighbors and resets run progress', () {
      final graph = CampaignWorldGraph.standard();
      final state = CampaignExplorationState();

      state.enterNode(CampaignNodeId.damageAssembly, graph);
      expect(state.currentNode, CampaignNodeId.damageAssembly);
      expect(state.visitedNodeIds, {CampaignNodeId.damageAssembly});
      expect(
        state.revealedNodeIds,
        containsAll(<CampaignNodeId>[
          CampaignNodeId.damageWorkshop,
          CampaignNodeId.damageOverflow,
          CampaignNodeId.damageDashCache,
          CampaignNodeId.damageUpperArchive,
          CampaignNodeId.damageTurretControl,
        ]),
      );

      state
        ..revealRegion(CampaignRegion.damageLab, graph)
        ..activateCheckpoint(CampaignNodeId.damageWorkshop, graph)
        ..unlockShortcut(CampaignWorldGraph.temporalHubLiftId)
        ..collectCoreSignature(CampaignRegion.damageLab)
        ..enterNode(CampaignNodeId.damageOverflow, graph);
      expect(
        state.unlockedShortcutIds,
        contains(CampaignWorldGraph.temporalHubLiftId),
      );
      expect(state.checkpointNodeId, CampaignNodeId.damageWorkshop);
      state.reset();
      expect(state.currentNode, isNull);
      expect(state.visitedNodeIds, isEmpty);
      expect(state.revealedNodeIds, isEmpty);
      expect(state.unlockedShortcutIds, isEmpty);
      expect(state.coreSignatures, isEmpty);
      expect(state.unlockedTraversalAbilities, isEmpty);
      expect(state.activatedTerrainNodeIds, isEmpty);
      expect(state.mappedRegions, isEmpty);
      expect(state.checkpointNodeId, isNull);
    });

    test('regional cores unlock traversal abilities in campaign order', () {
      final state = CampaignExplorationState();

      state.collectCoreSignature(CampaignRegion.damageLab);
      expect(state.unlockedTraversalAbilities, <CampaignTraversalAbility>{
        CampaignTraversalAbility.wallJump,
      });

      state.collectCoreSignature(CampaignRegion.temporalHall);
      expect(
        state.hasTraversalAbility(CampaignTraversalAbility.airDash),
        isTrue,
      );

      state
        ..collectCoreSignature(CampaignRegion.collisionArchive)
        ..activateTerrainNode('terrain.test.bridge');
      expect(
        state.unlockedTraversalAbilities,
        containsAll(CampaignTraversalAbility.values),
      );
      expect(state.activatedTerrainNodeIds, contains('terrain.test.bridge'));
    });

    test('optimizer route requires cores and all three applied patches', () {
      final graph = CampaignWorldGraph.standard();
      final state = CampaignExplorationState();
      final gate = graph.connectionBetween(
        CampaignNodeId.bootSector,
        CampaignNodeId.optimizerCore,
      );

      expect(state.canTraverse(gate, weapon: PlayerWeapon.gun), isFalse);
      state
        ..collectCoreSignature(CampaignRegion.damageLab)
        ..collectCoreSignature(CampaignRegion.temporalHall)
        ..collectCoreSignature(CampaignRegion.collisionArchive);
      expect(state.hasAllCoreSignatures, isTrue);
      expect(gate.requirement, CampaignRouteRequirement.optimizerGateReady);
      expect(state.canTraverse(gate, weapon: PlayerWeapon.gun), isFalse);
      expect(
        state.canTraverse(
          gate,
          weapon: PlayerWeapon.gun,
          optimizerGateReady: true,
        ),
        isTrue,
      );
    });

    test('weapon-specific routes never leak to another loadout', () {
      final graph = CampaignWorldGraph.standard();
      final state = CampaignExplorationState();
      const routes = <(CampaignNodeId, CampaignNodeId, PlayerWeapon)>[
        (
          CampaignNodeId.damageAssembly,
          CampaignNodeId.damageDashCache,
          PlayerWeapon.sword,
        ),
        (
          CampaignNodeId.damageAssembly,
          CampaignNodeId.damageUpperArchive,
          PlayerWeapon.gauntlet,
        ),
        (
          CampaignNodeId.damageAssembly,
          CampaignNodeId.damageTurretControl,
          PlayerWeapon.gun,
        ),
        (
          CampaignNodeId.temporalFracture,
          CampaignNodeId.temporalDashRift,
          PlayerWeapon.sword,
        ),
        (
          CampaignNodeId.temporalFracture,
          CampaignNodeId.temporalUpperLoop,
          PlayerWeapon.gauntlet,
        ),
        (
          CampaignNodeId.temporalFracture,
          CampaignNodeId.temporalRelayControl,
          PlayerWeapon.gun,
        ),
        (
          CampaignNodeId.collisionFracture,
          CampaignNodeId.collisionVectorCache,
          PlayerWeapon.sword,
        ),
        (
          CampaignNodeId.collisionFracture,
          CampaignNodeId.collisionUpperMatrix,
          PlayerWeapon.gauntlet,
        ),
        (
          CampaignNodeId.collisionFracture,
          CampaignNodeId.collisionPrismControl,
          PlayerWeapon.gun,
        ),
      ];

      for (final route in routes) {
        final connection = graph.connectionBetween(route.$1, route.$2);
        for (final weapon in PlayerWeapon.values) {
          expect(
            state.canTraverse(connection, weapon: weapon),
            weapon == route.$3,
            reason: '${route.$2} leaked to ${weapon.name}',
          );
        }
      }
    });
  });

  group('platformer traversal contract', () {
    test('safe required route passes for all three weapons', () {
      const route = <TraversalSegment>[
        TraversalSegment(
          id: 'entry-step',
          rise: 72,
          gap: 90,
          landingWidth: 140,
        ),
        TraversalSegment(
          id: 'boss-approach',
          rise: 80,
          gap: 120,
          landingWidth: 96,
        ),
      ];

      for (final weapon in PlayerWeapon.values) {
        expect(
          PlatformerTraversalContract.validateRequiredRoute(
            route,
            weapon: weapon,
          ),
          isEmpty,
        );
      }
    });

    test('unsafe required geometry reports every blocking cause', () {
      const route = <TraversalSegment>[
        TraversalSegment(
          id: 'unsafe-stack',
          rise: 124,
          gap: 150,
          landingWidth: 64,
          requirement: TraversalAbilityRequirement.gauntletDoubleJump,
          requiresMovingPlatform: true,
        ),
      ];

      final violations = PlatformerTraversalContract.validateRequiredRoute(
        route,
        weapon: PlayerWeapon.sword,
      );
      expect(violations, hasLength(5));
      expect(
        violations.map((violation) => violation.reason).join(' '),
        contains('gauntletDoubleJump'),
      );
    });

    test('optional weapon routes may exceed the universal budget', () {
      const route = <TraversalSegment>[
        TraversalSegment(
          id: 'sword-secret',
          rise: 0,
          gap: 210,
          landingWidth: 80,
          requiredForCompletion: false,
          requirement: TraversalAbilityRequirement.swordDash,
        ),
      ];

      expect(
        PlatformerTraversalContract.validateRequiredRoute(
          route,
          weapon: PlayerWeapon.gun,
        ),
        isEmpty,
      );
    });
  });
}
