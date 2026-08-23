import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/environment/campaign_room_objective_component.dart';

enum RegionalRoomObjectiveMode { ordered, anyOrder, timedAnyOrder }

enum RegionalRoomObjectiveCompletionWindow {
  none,
  hazardInactive,
  platformMerged,
}

final class RegionalRoomObjectiveSpec {
  const RegionalRoomObjectiveSpec({
    required this.nodeId,
    required this.mode,
    required this.visualStyle,
    required this.objectiveLocalizationKey,
    required this.completionLocalizationKey,
    required this.interactionLocalizationKey,
    required this.activationOrder,
    this.timeLimitSeconds,
    this.disabledHazardSourceId,
    this.completionWindow = RegionalRoomObjectiveCompletionWindow.none,
  }) : assert(activationOrder.length > 1),
       assert(
         mode == RegionalRoomObjectiveMode.timedAnyOrder
             ? timeLimitSeconds != null && timeLimitSeconds > 0
             : timeLimitSeconds == null,
       );

  final CampaignNodeId nodeId;
  final RegionalRoomObjectiveMode mode;
  final CampaignRoomObjectiveVisualStyle visualStyle;
  final String objectiveLocalizationKey;
  final String completionLocalizationKey;
  final String interactionLocalizationKey;
  final List<int> activationOrder;
  final double? timeLimitSeconds;
  final String? disabledHazardSourceId;
  final RegionalRoomObjectiveCompletionWindow completionWindow;

  int get requiredNodeCount => activationOrder.length;

  int activationOrdinalFor(int nodeIndex) =>
      activationOrder.indexOf(nodeIndex) + 1;
}

abstract final class RegionalRoomObjectiveCatalog {
  static final Map<CampaignNodeId, RegionalRoomObjectiveSpec>
  _specs = <CampaignNodeId, RegionalRoomObjectiveSpec>{
    CampaignNodeId.temporalAscent: RegionalRoomObjectiveSpec(
      nodeId: CampaignNodeId.temporalAscent,
      mode: RegionalRoomObjectiveMode.ordered,
      visualStyle: CampaignRoomObjectiveVisualStyle.clockAnchor,
      objectiveLocalizationKey: 'objective.temporalAscentTask',
      completionLocalizationKey: 'objective.temporalAscentComplete',
      interactionLocalizationKey: 'interaction.syncClockAnchor',
      activationOrder: const <int>[0, 1, 2],
    ),
    CampaignNodeId.temporalFracture: RegionalRoomObjectiveSpec(
      nodeId: CampaignNodeId.temporalFracture,
      mode: RegionalRoomObjectiveMode.timedAnyOrder,
      visualStyle: CampaignRoomObjectiveVisualStyle.echoRelay,
      objectiveLocalizationKey: 'objective.temporalFractureTask',
      completionLocalizationKey: 'objective.temporalFractureComplete',
      interactionLocalizationKey: 'interaction.linkEchoRelay',
      activationOrder: const <int>[0, 1],
      timeLimitSeconds: 9,
      disabledHazardSourceId: 'hazard.temporal-hall.fracture.timeline-seam',
    ),
    CampaignNodeId.temporalPendulum: RegionalRoomObjectiveSpec(
      nodeId: CampaignNodeId.temporalPendulum,
      mode: RegionalRoomObjectiveMode.ordered,
      visualStyle: CampaignRoomObjectiveVisualStyle.rewindLock,
      objectiveLocalizationKey: 'objective.temporalPendulumTask',
      completionLocalizationKey: 'objective.temporalPendulumComplete',
      interactionLocalizationKey: 'interaction.releaseRewindLock',
      activationOrder: const <int>[2, 1, 0],
      disabledHazardSourceId: 'hazard.temporal-hall.pendulum.central-crusher',
    ),
    CampaignNodeId.collisionCompression: RegionalRoomObjectiveSpec(
      nodeId: CampaignNodeId.collisionCompression,
      mode: RegionalRoomObjectiveMode.anyOrder,
      visualStyle: CampaignRoomObjectiveVisualStyle.pressureValve,
      objectiveLocalizationKey: 'objective.collisionCompressionTask',
      completionLocalizationKey: 'objective.collisionCompressionComplete',
      interactionLocalizationKey: 'interaction.releasePressureValve',
      activationOrder: const <int>[0, 1],
      disabledHazardSourceId:
          'hazard.collision-archive.compression.central-piston',
    ),
    CampaignNodeId.collisionFracture: RegionalRoomObjectiveSpec(
      nodeId: CampaignNodeId.collisionFracture,
      mode: RegionalRoomObjectiveMode.ordered,
      visualStyle: CampaignRoomObjectiveVisualStyle.phaseShard,
      objectiveLocalizationKey: 'objective.collisionFractureTask',
      completionLocalizationKey: 'objective.collisionFractureComplete',
      interactionLocalizationKey: 'interaction.alignPhaseShard',
      activationOrder: const <int>[0, 2, 1],
      disabledHazardSourceId: 'hazard.collision-archive.fracture.phase-slice',
      completionWindow: RegionalRoomObjectiveCompletionWindow.hazardInactive,
    ),
    CampaignNodeId.collisionMerge: RegionalRoomObjectiveSpec(
      nodeId: CampaignNodeId.collisionMerge,
      mode: RegionalRoomObjectiveMode.ordered,
      visualStyle: CampaignRoomObjectiveVisualStyle.polarityCoil,
      objectiveLocalizationKey: 'objective.collisionMergeTask',
      completionLocalizationKey: 'objective.collisionMergeComplete',
      interactionLocalizationKey: 'interaction.balancePolarityCoil',
      activationOrder: const <int>[0, 2, 1],
      disabledHazardSourceId: 'hazard.collision-archive.merge.fusion-axis',
      completionWindow: RegionalRoomObjectiveCompletionWindow.platformMerged,
    ),
  };

  static RegionalRoomObjectiveSpec forNode(CampaignNodeId nodeId) {
    final spec = _specs[nodeId];
    if (spec == null) {
      throw StateError('Campaign node has no regional objective: $nodeId');
    }
    return spec;
  }

  static Iterable<RegionalRoomObjectiveSpec> get values => _specs.values;
}
