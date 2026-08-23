import 'package:patch_world/game/combat/player_weapon.dart';

enum CampaignRegion {
  bootSector,
  damageLab,
  temporalHall,
  collisionArchive,
  optimizerCore,
}

enum CampaignNodeKind { hub, combat, traversal, boss, secret, finalBoss }

enum CampaignNodeEntry { west, east }

/// Implemented by independently loaded campaign scenes so exploration state
/// follows the scene itself instead of inferring a node from player X.
abstract interface class CampaignNodeRoom {
  CampaignNodeId get campaignNodeId;
}

/// Optional scene-local guard for temporary locks such as a sealed encounter.
/// It is consulted only by direct travel, never by the world-map availability
/// predicate, so temporary combat state cannot corrupt exploration topology.
abstract interface class CampaignNodeTravelGuard {
  bool canLeaveCampaignNode(CampaignNodeId targetNode);
}

enum CampaignNodeId {
  bootSector,
  damageWorkshop,
  damageAssembly,
  damageOverflow,
  overflowWarden,
  damageDashCache,
  damageUpperArchive,
  damageTurretControl,
  temporalAscent,
  temporalFracture,
  temporalDashRift,
  temporalUpperLoop,
  temporalRelayControl,
  temporalPendulum,
  chronoJailer,
  collisionCompression,
  collisionFracture,
  collisionVectorCache,
  collisionUpperMatrix,
  collisionPrismControl,
  collisionMerge,
  kernelChimera,
  optimizerCore,
}

enum CampaignRouteRequirement {
  universal,
  swordDash,
  gauntletDoubleJump,
  gunRangedSwitch,
  unlockedShortcut,
  allCoreSignatures,
  optimizerGateReady,
}

final class CampaignNodeDefinition {
  const CampaignNodeDefinition({
    required this.id,
    required this.region,
    required this.kind,
    required this.mapX,
    required this.mapY,
    this.isCoreRoom = true,
  });

  final CampaignNodeId id;
  final CampaignRegion region;
  final CampaignNodeKind kind;
  final int mapX;
  final int mapY;
  final bool isCoreRoom;
}

final class CampaignWorldConnection {
  const CampaignWorldConnection({
    required this.from,
    required this.to,
    this.requirement = CampaignRouteRequirement.universal,
    this.unlockId,
    this.bidirectional = true,
  });

  final CampaignNodeId from;
  final CampaignNodeId to;
  final CampaignRouteRequirement requirement;
  final String? unlockId;
  final bool bidirectional;

  bool touches(CampaignNodeId nodeId) => from == nodeId || to == nodeId;

  CampaignNodeId other(CampaignNodeId nodeId) {
    if (from == nodeId) return to;
    if (bidirectional && to == nodeId) return from;
    throw StateError('$nodeId is not an entrance of $from -> $to.');
  }

  bool permits({
    required PlayerWeapon weapon,
    required Set<String> unlockedShortcutIds,
    required bool hasAllCoreSignatures,
    bool optimizerGateReady = false,
  }) => switch (requirement) {
    CampaignRouteRequirement.universal => true,
    CampaignRouteRequirement.swordDash => weapon == PlayerWeapon.sword,
    CampaignRouteRequirement.gauntletDoubleJump =>
      weapon == PlayerWeapon.gauntlet,
    CampaignRouteRequirement.gunRangedSwitch => weapon == PlayerWeapon.gun,
    CampaignRouteRequirement.unlockedShortcut =>
      unlockId != null && unlockedShortcutIds.contains(unlockId),
    CampaignRouteRequirement.allCoreSignatures => hasAllCoreSignatures,
    CampaignRouteRequirement.optimizerGateReady => optimizerGateReady,
  };
}

/// Immutable source of truth for the campaign map.
///
/// The first release reuses the existing three combat cells and boss cell in
/// each region as fourteen core rooms. Secret weapon routes are modeled as
/// optional nodes so they can be implemented without ever blocking the main
/// route.
final class CampaignWorldGraph {
  CampaignWorldGraph({
    required Iterable<CampaignNodeDefinition> nodes,
    required Iterable<CampaignWorldConnection> connections,
  }) : nodes = Map<CampaignNodeId, CampaignNodeDefinition>.unmodifiable({
         for (final node in nodes) node.id: node,
       }),
       connections = List<CampaignWorldConnection>.unmodifiable(connections) {
    _validate();
  }

  factory CampaignWorldGraph.standard() => CampaignWorldGraph(
    nodes: const <CampaignNodeDefinition>[
      CampaignNodeDefinition(
        id: CampaignNodeId.bootSector,
        region: CampaignRegion.bootSector,
        kind: CampaignNodeKind.hub,
        mapX: 0,
        mapY: 0,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.damageWorkshop,
        region: CampaignRegion.damageLab,
        kind: CampaignNodeKind.combat,
        mapX: 1,
        mapY: 0,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.damageAssembly,
        region: CampaignRegion.damageLab,
        kind: CampaignNodeKind.traversal,
        mapX: 2,
        mapY: 0,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.damageOverflow,
        region: CampaignRegion.damageLab,
        kind: CampaignNodeKind.combat,
        mapX: 3,
        mapY: 0,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.overflowWarden,
        region: CampaignRegion.damageLab,
        kind: CampaignNodeKind.boss,
        mapX: 4,
        mapY: 0,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.damageDashCache,
        region: CampaignRegion.damageLab,
        kind: CampaignNodeKind.secret,
        mapX: 2,
        mapY: -1,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.damageUpperArchive,
        region: CampaignRegion.damageLab,
        kind: CampaignNodeKind.secret,
        mapX: 3,
        mapY: -1,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.damageTurretControl,
        region: CampaignRegion.damageLab,
        kind: CampaignNodeKind.secret,
        mapX: 2,
        mapY: 1,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.temporalAscent,
        region: CampaignRegion.temporalHall,
        kind: CampaignNodeKind.traversal,
        mapX: 4,
        mapY: -2,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.temporalFracture,
        region: CampaignRegion.temporalHall,
        kind: CampaignNodeKind.combat,
        mapX: 3,
        mapY: -2,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.temporalDashRift,
        region: CampaignRegion.temporalHall,
        kind: CampaignNodeKind.secret,
        mapX: 3,
        mapY: -3,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.temporalUpperLoop,
        region: CampaignRegion.temporalHall,
        kind: CampaignNodeKind.secret,
        mapX: 4,
        mapY: -3,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.temporalRelayControl,
        region: CampaignRegion.temporalHall,
        kind: CampaignNodeKind.secret,
        mapX: 2,
        mapY: -3,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.temporalPendulum,
        region: CampaignRegion.temporalHall,
        kind: CampaignNodeKind.traversal,
        mapX: 2,
        mapY: -2,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.chronoJailer,
        region: CampaignRegion.temporalHall,
        kind: CampaignNodeKind.boss,
        mapX: 1,
        mapY: -2,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.collisionCompression,
        region: CampaignRegion.collisionArchive,
        kind: CampaignNodeKind.combat,
        mapX: 4,
        mapY: 2,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.collisionFracture,
        region: CampaignRegion.collisionArchive,
        kind: CampaignNodeKind.traversal,
        mapX: 3,
        mapY: 2,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.collisionVectorCache,
        region: CampaignRegion.collisionArchive,
        kind: CampaignNodeKind.secret,
        mapX: 3,
        mapY: 3,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.collisionUpperMatrix,
        region: CampaignRegion.collisionArchive,
        kind: CampaignNodeKind.secret,
        mapX: 4,
        mapY: 3,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.collisionPrismControl,
        region: CampaignRegion.collisionArchive,
        kind: CampaignNodeKind.secret,
        mapX: 2,
        mapY: 3,
        isCoreRoom: false,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.collisionMerge,
        region: CampaignRegion.collisionArchive,
        kind: CampaignNodeKind.combat,
        mapX: 2,
        mapY: 2,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.kernelChimera,
        region: CampaignRegion.collisionArchive,
        kind: CampaignNodeKind.boss,
        mapX: 1,
        mapY: 2,
      ),
      CampaignNodeDefinition(
        id: CampaignNodeId.optimizerCore,
        region: CampaignRegion.optimizerCore,
        kind: CampaignNodeKind.finalBoss,
        mapX: -1,
        mapY: 0,
      ),
    ],
    connections: const <CampaignWorldConnection>[
      CampaignWorldConnection(
        from: CampaignNodeId.bootSector,
        to: CampaignNodeId.damageWorkshop,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.damageWorkshop,
        to: CampaignNodeId.damageAssembly,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.damageAssembly,
        to: CampaignNodeId.damageOverflow,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.damageOverflow,
        to: CampaignNodeId.overflowWarden,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.damageWorkshop,
        to: CampaignNodeId.damageOverflow,
        requirement: CampaignRouteRequirement.unlockedShortcut,
        unlockId: damageMaintenanceShortcutId,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.damageAssembly,
        to: CampaignNodeId.damageDashCache,
        requirement: CampaignRouteRequirement.swordDash,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.damageAssembly,
        to: CampaignNodeId.damageUpperArchive,
        requirement: CampaignRouteRequirement.gauntletDoubleJump,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.damageAssembly,
        to: CampaignNodeId.damageTurretControl,
        requirement: CampaignRouteRequirement.gunRangedSwitch,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.overflowWarden,
        to: CampaignNodeId.temporalAscent,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.bootSector,
        to: CampaignNodeId.temporalAscent,
        requirement: CampaignRouteRequirement.unlockedShortcut,
        unlockId: temporalHubAccessId,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.temporalAscent,
        to: CampaignNodeId.temporalFracture,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.temporalFracture,
        to: CampaignNodeId.temporalDashRift,
        requirement: CampaignRouteRequirement.swordDash,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.temporalFracture,
        to: CampaignNodeId.temporalUpperLoop,
        requirement: CampaignRouteRequirement.gauntletDoubleJump,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.temporalFracture,
        to: CampaignNodeId.temporalRelayControl,
        requirement: CampaignRouteRequirement.gunRangedSwitch,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.temporalFracture,
        to: CampaignNodeId.temporalPendulum,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.temporalPendulum,
        to: CampaignNodeId.chronoJailer,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.chronoJailer,
        to: CampaignNodeId.collisionCompression,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.bootSector,
        to: CampaignNodeId.collisionCompression,
        requirement: CampaignRouteRequirement.unlockedShortcut,
        unlockId: collisionHubAccessId,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.collisionCompression,
        to: CampaignNodeId.collisionFracture,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.collisionFracture,
        to: CampaignNodeId.collisionVectorCache,
        requirement: CampaignRouteRequirement.swordDash,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.collisionFracture,
        to: CampaignNodeId.collisionUpperMatrix,
        requirement: CampaignRouteRequirement.gauntletDoubleJump,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.collisionFracture,
        to: CampaignNodeId.collisionPrismControl,
        requirement: CampaignRouteRequirement.gunRangedSwitch,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.collisionFracture,
        to: CampaignNodeId.collisionMerge,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.collisionMerge,
        to: CampaignNodeId.kernelChimera,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.chronoJailer,
        to: CampaignNodeId.bootSector,
        requirement: CampaignRouteRequirement.unlockedShortcut,
        unlockId: temporalHubLiftId,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.kernelChimera,
        to: CampaignNodeId.bootSector,
        requirement: CampaignRouteRequirement.unlockedShortcut,
        unlockId: collisionHubLiftId,
      ),
      CampaignWorldConnection(
        from: CampaignNodeId.bootSector,
        to: CampaignNodeId.optimizerCore,
        requirement: CampaignRouteRequirement.optimizerGateReady,
      ),
    ],
  );

  static const String temporalHubLiftId = 'shortcut.temporal-hub-lift';
  static const String collisionHubLiftId = 'shortcut.collision-hub-lift';
  static const String damageMaintenanceShortcutId =
      'shortcut.damage-maintenance-lift';
  static const String temporalHubAccessId = 'route.temporal-hub-access';
  static const String collisionHubAccessId = 'route.collision-hub-access';

  static const List<CampaignNodeId> damageMainPath = <CampaignNodeId>[
    CampaignNodeId.damageWorkshop,
    CampaignNodeId.damageAssembly,
    CampaignNodeId.damageOverflow,
    CampaignNodeId.overflowWarden,
  ];
  static const List<CampaignNodeId> damageSubQuestPath = <CampaignNodeId>[
    CampaignNodeId.damageWorkshop,
    CampaignNodeId.damageAssembly,
    CampaignNodeId.damageOverflow,
  ];
  static const CampaignNodeId damageLabBossNode = CampaignNodeId.overflowWarden;
  static const List<CampaignNodeId> temporalMainPath = <CampaignNodeId>[
    CampaignNodeId.temporalAscent,
    CampaignNodeId.temporalFracture,
    CampaignNodeId.temporalPendulum,
    CampaignNodeId.chronoJailer,
  ];
  static const List<CampaignNodeId> temporalSubQuestPath = <CampaignNodeId>[
    CampaignNodeId.temporalAscent,
    CampaignNodeId.temporalFracture,
    CampaignNodeId.temporalPendulum,
  ];
  static const CampaignNodeId temporalBossNode = CampaignNodeId.chronoJailer;
  static const List<CampaignNodeId> collisionMainPath = <CampaignNodeId>[
    CampaignNodeId.collisionCompression,
    CampaignNodeId.collisionFracture,
    CampaignNodeId.collisionMerge,
    CampaignNodeId.kernelChimera,
  ];
  static const List<CampaignNodeId> collisionSubQuestPath = <CampaignNodeId>[
    CampaignNodeId.collisionCompression,
    CampaignNodeId.collisionFracture,
    CampaignNodeId.collisionMerge,
  ];
  static const CampaignNodeId collisionBossNode = CampaignNodeId.kernelChimera;

  static const Map<CampaignNodeId, CampaignNodeId> linearNextNode =
      <CampaignNodeId, CampaignNodeId>{
        CampaignNodeId.damageWorkshop: CampaignNodeId.damageAssembly,
        CampaignNodeId.damageAssembly: CampaignNodeId.damageOverflow,
        CampaignNodeId.damageOverflow: CampaignNodeId.overflowWarden,
        CampaignNodeId.overflowWarden: CampaignNodeId.temporalAscent,
        CampaignNodeId.temporalAscent: CampaignNodeId.temporalFracture,
        CampaignNodeId.temporalFracture: CampaignNodeId.temporalPendulum,
        CampaignNodeId.temporalPendulum: CampaignNodeId.chronoJailer,
        CampaignNodeId.chronoJailer: CampaignNodeId.collisionCompression,
        CampaignNodeId.collisionCompression: CampaignNodeId.collisionFracture,
        CampaignNodeId.collisionFracture: CampaignNodeId.collisionMerge,
        CampaignNodeId.collisionMerge: CampaignNodeId.kernelChimera,
      };

  static bool isLinearChapterTransition(
    CampaignNodeId from,
    CampaignNodeId to,
  ) => linearNextNode[from] == to;

  static bool isChapterBossNode(CampaignNodeId nodeId) =>
      nodeId == damageLabBossNode ||
      nodeId == temporalBossNode ||
      nodeId == collisionBossNode;

  static int chapterIndexForNode(CampaignNodeId nodeId) {
    if (damageMainPath.contains(nodeId)) return 1;
    if (temporalMainPath.contains(nodeId)) return 2;
    if (collisionMainPath.contains(nodeId)) return 3;
    return 0;
  }

  final Map<CampaignNodeId, CampaignNodeDefinition> nodes;
  final List<CampaignWorldConnection> connections;

  Iterable<CampaignWorldConnection> connectionsFrom(CampaignNodeId nodeId) =>
      connections.where(
        (connection) =>
            connection.from == nodeId ||
            (connection.bidirectional && connection.to == nodeId),
      );

  Iterable<CampaignNodeId> neighborsOf(CampaignNodeId nodeId) =>
      connectionsFrom(nodeId).map((connection) => connection.other(nodeId));

  int get coreRoomCount => nodes.values.where((node) => node.isCoreRoom).length;

  CampaignWorldConnection connectionBetween(
    CampaignNodeId first,
    CampaignNodeId second,
  ) => connections.singleWhere(
    (connection) =>
        (connection.from == first && connection.to == second) ||
        (connection.bidirectional &&
            connection.from == second &&
            connection.to == first),
  );

  void _validate() {
    if (!nodes.containsKey(CampaignNodeId.bootSector)) {
      throw ArgumentError('Campaign graph must contain the Boot Sector.');
    }
    for (final connection in connections) {
      if (!nodes.containsKey(connection.from) ||
          !nodes.containsKey(connection.to)) {
        throw ArgumentError(
          'Connection ${connection.from} -> ${connection.to} has a missing node.',
        );
      }
      if (connection.from == connection.to) {
        throw ArgumentError('Campaign connections cannot target themselves.');
      }
      if (connection.requirement == CampaignRouteRequirement.unlockedShortcut &&
          connection.unlockId == null) {
        throw ArgumentError('Shortcut connections need an unlock ID.');
      }
    }
  }
}
