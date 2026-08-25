import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/ordinary_jump_reachability.dart';
import 'package:patch_world/game/components/environment/optimizer_arena_stage_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rooms/maps/regional_campaign_room_layout.dart';
import 'package:patch_world/game/rules/rule_context.dart';

void main() {
  late RegionalCampaignRoomLayoutCatalog regionalLayouts;

  setUpAll(() async {
    regionalLayouts = RegionalCampaignRoomLayoutCatalog.fromJsonSources(
      temporalHallSource: await File(
        RegionalCampaignRoomLayoutCatalog.temporalHallAssetPath,
      ).readAsString(),
      collisionArchiveSource: await File(
        RegionalCampaignRoomLayoutCatalog.collisionArchiveAssetPath,
      ).readAsString(),
    );
  });

  test('Temporal Hall and Collision Archive mandatory interactions need only '
      'sword movement and one ordinary jump', () {
    for (final layout in regionalLayouts.rooms) {
      final surfaces = layout.surfaces
          .where((surface) => !surface.isBoundary)
          .map(
            (surface) =>
                OrdinaryJumpSurface(id: surface.id, bounds: surface.bounds),
          )
          .toList(growable: false);
      final anchors = _requiredRegionalAnchors(layout);

      for (final entry in CampaignNodeEntry.values) {
        final spawn = layout.spawnFor(entry);
        final result = OrdinaryJumpReachability.analyze(
          surfaces: surfaces,
          start: OrdinaryJumpAnchor(
            id: 'spawn.${entry.name}',
            // PlayerComponent has a 32 px collision body. Authored regional
            // spawns begin 20 px above their floor and settle naturally.
            feet: Offset(spawn.x, spawn.y + 16),
            settleDistance: 24,
          ),
          requiredAnchors: anchors,
        );

        for (final anchor in anchors) {
          expect(
            result.isAnchorReachable(anchor.id),
            isTrue,
            reason:
                '${layout.nodeId.name}/${entry.name}/${anchor.id} has no '
                'static ordinary-jump route. Reachable surfaces: '
                '${result.reachableSurfaceIds.join(', ')}',
          );
          expect(
            result.surfacePathTo(anchor.id),
            isNotEmpty,
            reason: '${layout.nodeId.name}/${anchor.id} needs a real path',
          );
        }
      }
    }
  });

  testWidgets(
    'Optimizer Core has a static ordinary-jump route across both firewalls '
    'and up to sword melee height',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.optimizerCore);
      await tester.pumpWidget(
        MaterialApp(
          home: GameWidget<PatchWorldGame>(
            game: game,
            overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
              OverlayIds.ending: (_, _) => const SizedBox.shrink(),
            },
          ),
        ),
      );
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);
      await tester.pump();

      final room = game.world.activeRoom! as BossRoomController;
      final staticSurfaces = room.children
          .whereType<PlatformSurfaceComponent>()
          .where(
            (surface) =>
                !surface.isBoundary &&
                surface is! OptimizerPhasePlatformComponent &&
                surface is! OptimizerPhaseBreakablePlatformComponent,
          )
          .map(
            (surface) => OrdinaryJumpSurface(
              id:
                  'optimizer.static.'
                  '${surface.position.x.toInt()}.'
                  '${surface.position.y.toInt()}',
              bounds: surface.bounds,
            ),
          )
          .toList(growable: false);
      const anchors = <OrdinaryJumpAnchor>[
        OrdinaryJumpAnchor(id: 'legacy-terminal', feet: Offset(960, 1024)),
        OrdinaryJumpAnchor(id: 'right-arena-floor', feet: Offset(1640, 1024)),
        OrdinaryJumpAnchor(id: 'sword-melee-tier', feet: Offset(960, 544)),
      ];
      final result = OrdinaryJumpReachability.analyze(
        surfaces: staticSurfaces,
        start: OrdinaryJumpAnchor(
          id: 'optimizer-spawn',
          feet: Offset(room.playerSpawn.x, room.playerSpawn.y + 16),
          settleDistance: 24,
        ),
        requiredAnchors: anchors,
      );

      for (final anchor in anchors) {
        expect(
          result.isAnchorReachable(anchor.id),
          isTrue,
          reason:
              '${anchor.id} must not require dash, double jump, wall jump, '
              'air dash, phase platforms, breakables, or jump pads',
        );
      }
      final meleePath = result.surfacePathTo('sword-melee-tier')!;
      expect(meleePath, hasLength(greaterThanOrEqualTo(6)));
      final firewalls = staticSurfaces
          .where(
            (surface) =>
                surface.bounds.left == 560 || surface.bounds.left == 1318,
          )
          .toList(growable: false);
      expect(firewalls, hasLength(2));
      expect(
        firewalls.every(
          (surface) =>
              surface.bounds.height <=
              OrdinaryJumpReachability.swordBaseline.maximumRise,
        ),
        isTrue,
        reason: 'Both visible firewall blocks must be single-jump clearable.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

List<OrdinaryJumpAnchor> _requiredRegionalAnchors(
  RegionalCampaignRoomLayout layout,
) {
  const requiredAnchorIds = <String>[
    RegionalCampaignAnchorId.backDoor,
    RegionalCampaignAnchorId.forwardDoor,
    RegionalCampaignAnchorId.checkpoint,
    RegionalCampaignAnchorId.qaRecord,
    RegionalCampaignAnchorId.repairStation,
    RegionalCampaignAnchorId.loadoutEvent,
    RegionalCampaignAnchorId.hubShortcutDoor,
    RegionalCampaignAnchorId.questReward,
    RegionalCampaignAnchorId.bossReward,
    RegionalCampaignAnchorId.exitTerminal,
    RegionalCampaignAnchorId.hubLift,
    RegionalCampaignAnchorId.regionBranchDoor,
  ];
  return <OrdinaryJumpAnchor>[
    for (final id in requiredAnchorIds)
      if (layout.anchor(id) case final point?)
        OrdinaryJumpAnchor(
          id: id,
          feet: Offset(point.x, point.y),
          // Several bottom-anchored terminals hover 6 px over the artwork;
          // the player can stand on the supporting floor within interaction
          // range without a movement ability.
          settleDistance: 24,
        ),
    for (var index = 0; index < layout.objectiveNodes.length; index += 1)
      OrdinaryJumpAnchor(
        id: 'objective.$index',
        feet: Offset(
          layout.objectiveNodes[index].x,
          layout.objectiveNodes[index].y,
        ),
      ),
  ];
}
