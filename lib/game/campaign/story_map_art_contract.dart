import 'dart:ui';

import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';

/// Runtime layers that every authored story map must provide.
///
/// The collision layer is the single source of truth for both the visible
/// walkable silhouette and physics. Decorative far/mid artwork must never
/// imply a platform, door, or hazard that is absent from this layer.
enum StoryMapArtLayer { far, mid, collision }

/// Immutable art-direction contract for one existing campaign node.
///
/// This deliberately keys presentation data with [CampaignNodeId] instead of
/// introducing replacement room ids, preserving saves and campaign topology
/// while all story-map artwork is rebuilt.
final class StoryMapArtSpec {
  const StoryMapArtSpec({
    required this.nodeId,
    required this.theme,
    required this.motif,
    required this.displayNameKo,
    required this.displayNameEn,
    required this.recommendedSize,
    this.gridSize = StoryMapArtCatalog.gridSize,
    this.layers = StoryMapArtCatalog.requiredLayers,
    required this.mainPathUniversal,
    this.weaponSecret,
  });

  final CampaignNodeId nodeId;
  final StoryRegionVisualTheme theme;
  final StoryRoomVisualMotif motif;
  final String displayNameKo;
  final String displayNameEn;
  final Size recommendedSize;
  final int gridSize;
  final Set<StoryMapArtLayer> layers;

  /// True only when the room belongs to the weapon-independent story route.
  final bool mainPathUniversal;

  /// The traversal identity of an optional weapon route; null on every core
  /// story room, hub, chapter boss, and final boss.
  final PlayerWeapon? weaponSecret;

  bool get isWeaponSecret => weaponSecret != null;
}

/// Source of truth for the visual rebuild of all 23 story-mode map nodes.
///
/// Survival mode intentionally has no entry here and keeps its current arena
/// renderer and content pipeline.
abstract final class StoryMapArtCatalog {
  static const int gridSize = 32;

  static const Set<StoryMapArtLayer> requiredLayers = <StoryMapArtLayer>{
    StoryMapArtLayer.far,
    StoryMapArtLayer.mid,
    StoryMapArtLayer.collision,
  };

  static const List<StoryMapArtSpec> specs = <StoryMapArtSpec>[
    StoryMapArtSpec(
      nodeId: CampaignNodeId.bootSector,
      theme: StoryRegionVisualTheme.boot,
      motif: StoryRoomVisualMotif.hub,
      displayNameKo: '콜드 부트 정거장',
      displayNameEn: 'Cold Boot Station',
      recommendedSize: Size(1440, 832),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.damageWorkshop,
      theme: StoryRegionVisualTheme.damage,
      motif: StoryRoomVisualMotif.intake,
      displayNameKo: '스크랩 접수장',
      displayNameEn: 'Scrap Intake',
      recommendedSize: Size(1920, 1088),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.damageAssembly,
      theme: StoryRegionVisualTheme.damage,
      motif: StoryRoomVisualMotif.assembly,
      displayNameKo: '수직 조립 샤프트',
      displayNameEn: 'Vertical Assembly Shaft',
      recommendedSize: Size(1920, 1440),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.damageOverflow,
      theme: StoryRegionVisualTheme.damage,
      motif: StoryRoomVisualMotif.overflow,
      displayNameKo: '과열 배출로',
      displayNameEn: 'Overheat Spillway',
      recommendedSize: Size(2400, 1088),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.overflowWarden,
      theme: StoryRegionVisualTheme.damage,
      motif: StoryRoomVisualMotif.boss,
      displayNameKo: '압력 격납고',
      displayNameEn: 'Pressure Containment Hangar',
      recommendedSize: Size(1440, 832),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.damageDashCache,
      theme: StoryRegionVisualTheme.damage,
      motif: StoryRoomVisualMotif.dashSecret,
      displayNameKo: '절단 컨베이어',
      displayNameEn: 'Cutting Conveyor',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.sword,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.damageUpperArchive,
      theme: StoryRegionVisualTheme.damage,
      motif: StoryRoomVisualMotif.verticalSecret,
      displayNameKo: '폐부품 천장고',
      displayNameEn: 'Overhead Scrap Archive',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.gauntlet,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.damageTurretControl,
      theme: StoryRegionVisualTheme.damage,
      motif: StoryRoomVisualMotif.rangedSecret,
      displayNameKo: '사격 교정실',
      displayNameEn: 'Ballistic Calibration Room',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.gun,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.temporalAscent,
      theme: StoryRegionVisualTheme.temporal,
      motif: StoryRoomVisualMotif.ascent,
      displayNameKo: '정지 시계탑 하부',
      displayNameEn: 'Stilled Clocktower Base',
      recommendedSize: Size(1920, 1632),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.temporalFracture,
      theme: StoryRegionVisualTheme.temporal,
      motif: StoryRoomVisualMotif.fracture,
      displayNameKo: '쌍둥이 시간선',
      displayNameEn: 'Twin Timelines',
      recommendedSize: Size(2400, 1088),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.temporalDashRift,
      theme: StoryRegionVisualTheme.temporal,
      motif: StoryRoomVisualMotif.dashSecret,
      displayNameKo: '초침 균열로',
      displayNameEn: 'Second-Hand Rift',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.sword,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.temporalUpperLoop,
      theme: StoryRegionVisualTheme.temporal,
      motif: StoryRoomVisualMotif.verticalSecret,
      displayNameKo: '역행 관측대',
      displayNameEn: 'Reversal Observatory',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.gauntlet,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.temporalRelayControl,
      theme: StoryRegionVisualTheme.temporal,
      motif: StoryRoomVisualMotif.rangedSecret,
      displayNameKo: '지연 신호실',
      displayNameEn: 'Delay Signal Room',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.gun,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.temporalPendulum,
      theme: StoryRegionVisualTheme.temporal,
      motif: StoryRoomVisualMotif.pendulum,
      displayNameKo: '대진자 종루',
      displayNameEn: 'Great Pendulum Belfry',
      recommendedSize: Size(1920, 1440),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.chronoJailer,
      theme: StoryRegionVisualTheme.temporal,
      motif: StoryRoomVisualMotif.boss,
      displayNameKo: '시간 감옥',
      displayNameEn: 'Time Prison',
      recommendedSize: Size(1440, 832),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.collisionCompression,
      theme: StoryRegionVisualTheme.collision,
      motif: StoryRoomVisualMotif.compression,
      displayNameKo: '압축 협곡',
      displayNameEn: 'Compression Gorge',
      recommendedSize: Size(2400, 1088),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.collisionFracture,
      theme: StoryRegionVisualTheme.collision,
      motif: StoryRoomVisualMotif.fracture,
      displayNameKo: '분할 프리즘 광맥',
      displayNameEn: 'Fractured Prism Vein',
      recommendedSize: Size(1920, 1440),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.collisionVectorCache,
      theme: StoryRegionVisualTheme.collision,
      motif: StoryRoomVisualMotif.dashSecret,
      displayNameKo: '벡터 절단로',
      displayNameEn: 'Vector Shear Passage',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.sword,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.collisionUpperMatrix,
      theme: StoryRegionVisualTheme.collision,
      motif: StoryRoomVisualMotif.verticalSecret,
      displayNameKo: '부유 격자층',
      displayNameEn: 'Floating Matrix',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.gauntlet,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.collisionPrismControl,
      theme: StoryRegionVisualTheme.collision,
      motif: StoryRoomVisualMotif.rangedSecret,
      displayNameKo: '굴절 조준실',
      displayNameEn: 'Refraction Range',
      recommendedSize: Size(960, 544),
      mainPathUniversal: false,
      weaponSecret: PlayerWeapon.gun,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.collisionMerge,
      theme: StoryRegionVisualTheme.collision,
      motif: StoryRoomVisualMotif.merge,
      displayNameKo: '쌍극 융합교',
      displayNameEn: 'Bipolar Merge Bridge',
      recommendedSize: Size(2400, 1440),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.kernelChimera,
      theme: StoryRegionVisualTheme.collision,
      motif: StoryRoomVisualMotif.boss,
      displayNameKo: '키메라 융합노',
      displayNameEn: 'Chimera Fusion Furnace',
      recommendedSize: Size(1440, 832),
      mainPathUniversal: true,
    ),
    StoryMapArtSpec(
      nodeId: CampaignNodeId.optimizerCore,
      theme: StoryRegionVisualTheme.optimizer,
      motif: StoryRoomVisualMotif.finalCore,
      displayNameKo: '무결점의 심장',
      displayNameEn: 'Perfect Core',
      recommendedSize: Size(1920, 1088),
      mainPathUniversal: true,
    ),
  ];

  static final Map<CampaignNodeId, StoryMapArtSpec> byNode =
      Map<CampaignNodeId, StoryMapArtSpec>.unmodifiable(
        <CampaignNodeId, StoryMapArtSpec>{
          for (final spec in specs) spec.nodeId: spec,
        },
      );

  static StoryMapArtSpec specFor(CampaignNodeId nodeId) {
    final spec = byNode[nodeId];
    if (spec == null) {
      throw StateError('No story map art contract for ${nodeId.name}.');
    }
    return spec;
  }
}
