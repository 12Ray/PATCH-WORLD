import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

final class CampaignExplorationState {
  CampaignNodeId? currentNode;
  final Set<CampaignNodeId> visitedNodeIds = <CampaignNodeId>{};
  final Set<CampaignNodeId> revealedNodeIds = <CampaignNodeId>{};
  final Set<String> unlockedShortcutIds = <String>{};
  final Set<CampaignRegion> coreSignatures = <CampaignRegion>{};
  final Set<CampaignRegion> mappedRegions = <CampaignRegion>{};
  final Set<CampaignTraversalAbility> unlockedTraversalAbilities =
      <CampaignTraversalAbility>{};
  final Set<String> activatedTerrainNodeIds = <String>{};
  CampaignNodeId? checkpointNodeId;

  bool get hasAllCoreSignatures =>
      coreSignatures.containsAll(const <CampaignRegion>{
        CampaignRegion.damageLab,
        CampaignRegion.temporalHall,
        CampaignRegion.collisionArchive,
      });

  void enterNode(CampaignNodeId nodeId, CampaignWorldGraph graph) {
    if (!graph.nodes.containsKey(nodeId)) {
      throw ArgumentError.value(nodeId, 'nodeId', 'Unknown campaign node.');
    }
    currentNode = nodeId;
    visitedNodeIds.add(nodeId);
    revealedNodeIds
      ..add(nodeId)
      ..addAll(graph.neighborsOf(nodeId));
  }

  void revealRegion(CampaignRegion region, CampaignWorldGraph graph) {
    mappedRegions.add(region);
    revealedNodeIds.addAll(
      graph.nodes.values
          .where((node) => node.region == region)
          .map((node) => node.id),
    );
  }

  void activateCheckpoint(CampaignNodeId nodeId, CampaignWorldGraph graph) {
    if (!graph.nodes.containsKey(nodeId)) {
      throw ArgumentError.value(nodeId, 'nodeId', 'Unknown checkpoint node.');
    }
    checkpointNodeId = nodeId;
    enterNode(nodeId, graph);
  }

  void collectCoreSignature(CampaignRegion region) {
    if (region == CampaignRegion.damageLab ||
        region == CampaignRegion.temporalHall ||
        region == CampaignRegion.collisionArchive) {
      coreSignatures.add(region);
      final ability = switch (region) {
        CampaignRegion.damageLab => CampaignTraversalAbility.wallJump,
        CampaignRegion.temporalHall => CampaignTraversalAbility.airDash,
        CampaignRegion.collisionArchive =>
          CampaignTraversalAbility.terrainPulse,
        _ => null,
      };
      if (ability != null) unlockedTraversalAbilities.add(ability);
    }
  }

  bool hasTraversalAbility(CampaignTraversalAbility ability) =>
      unlockedTraversalAbilities.contains(ability);

  void unlockTraversalAbility(CampaignTraversalAbility ability) {
    unlockedTraversalAbilities.add(ability);
  }

  void activateTerrainNode(String nodeId) {
    if (nodeId.isNotEmpty) activatedTerrainNodeIds.add(nodeId);
  }

  void unlockShortcut(String shortcutId) {
    if (shortcutId.isNotEmpty) unlockedShortcutIds.add(shortcutId);
  }

  bool canTraverse(
    CampaignWorldConnection connection, {
    required PlayerWeapon weapon,
    bool optimizerGateReady = false,
  }) => connection.permits(
    weapon: weapon,
    unlockedShortcutIds: unlockedShortcutIds,
    hasAllCoreSignatures: hasAllCoreSignatures,
    optimizerGateReady: optimizerGateReady,
  );

  void reset() {
    currentNode = null;
    visitedNodeIds.clear();
    revealedNodeIds.clear();
    unlockedShortcutIds.clear();
    coreSignatures.clear();
    mappedRegions.clear();
    unlockedTraversalAbilities.clear();
    activatedTerrainNodeIds.clear();
    checkpointNodeId = null;
  }
}
