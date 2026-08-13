import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/rooms/four_cell_chapter_controller.dart';

final class RoomThreeController extends FourCellChapterController {
  RoomThreeController({required super.progress});

  @override
  PlatformSurfaceStyle get surfaceStyle => PlatformSurfaceStyle.collision;

  @override
  RoomBackdropStyle get backdropStyle => RoomBackdropStyle.collision;

  @override
  CampaignChapterBossKind get bossKind => CampaignChapterBossKind.kernelChimera;

  @override
  RunItemId get questRewardItem => RunItemId.vectorBoots;

  @override
  RunItemId get bossRewardItem => RunItemId.collisionPrism;

  @override
  String get recordLocalizationKey => 'quest.mergeLog';

  @override
  String get bossIntroLocalizationKey => 'boss.kernelChimera.intro';

  @override
  Color get chapterAccentColor => const Color(0xFF36E1FF);

  @override
  List<ChapterEnemySpawn> get enemySpawns => const <ChapterEnemySpawn>[
    ChapterEnemySpawn(0, PlatformerEnemyArchetype.vectorRam, 300, 972),
    ChapterEnemySpawn(0, PlatformerEnemyArchetype.polarityDrone, 700, 720),
    ChapterEnemySpawn(1, PlatformerEnemyArchetype.phaseMimic, 1160, 840),
    ChapterEnemySpawn(1, PlatformerEnemyArchetype.vectorRam, 1740, 972),
    ChapterEnemySpawn(2, PlatformerEnemyArchetype.shardLobber, 2100, 862),
    ChapterEnemySpawn(2, PlatformerEnemyArchetype.polarityDrone, 2700, 780),
  ];

  @override
  List<PlatformSurfaceComponent> buildChapterSurfaces() =>
      <PlatformSurfaceComponent>[
        surface(0, 0, 24, 1080, boundary: true),
        surface(worldSize.x - 24, 0, 24, 1080, boundary: true),
        // ROOM 3-1: vector compression lane.
        surface(0, 1024, 390, 56),
        surface(490, 1024, 470, 56),
        surface(90, 900, 200, 22),
        surface(330, 810, 170, 22),
        surface(650, 720, 200, 22),
        MovingPlatformComponent(
          start: Vector2(450, 920),
          end: Vector2(580, 690),
          size: Vector2(120, 22),
          periodSeconds: 3.5,
          style: surfaceStyle,
        ),
        // ROOM 3-2: phase fracture stacks.
        surface(960, 1024, 350, 56),
        surface(1410, 1024, 510, 56),
        surface(1040, 880, 200, 22),
        surface(1490, 780, 200, 22),
        surface(1710, 690, 160, 22),
        BreakablePlatformComponent(
          position: Vector2(1280, 720),
          size: Vector2(150, 22),
          style: surfaceStyle,
          breakDelay: .55,
        ),
        // ROOM 3-3: polarity merge chamber.
        surface(1920, 1024, 370, 56),
        surface(2390, 1024, 490, 56),
        surface(2000, 900, 210, 22),
        surface(2500, 790, 190, 22),
        surface(2690, 700, 150, 22),
        MovingPlatformComponent(
          start: Vector2(2240, 900),
          end: Vector2(2410, 690),
          size: Vector2(125, 22),
          periodSeconds: 3.2,
          style: surfaceStyle,
        ),
        BreakablePlatformComponent(
          position: Vector2(2600, 900),
          size: Vector2(150, 22),
          style: surfaceStyle,
          breakDelay: .65,
        ),
        // Boss cell.
        surface(2880, 1024, 960, 56),
        surface(3070, 850, 180, 22),
        surface(3530, 850, 180, 22),
      ];

  @override
  List<Component> buildChapterFeatures() => <Component>[
    DamagePitComponent(
      position: Vector2(390, 1024),
      size: Vector2(100, 56),
      style: surfaceStyle,
    ),
    DamagePitComponent(
      position: Vector2(1310, 1024),
      size: Vector2(100, 56),
      style: surfaceStyle,
    ),
    DamagePitComponent(
      position: Vector2(2290, 1024),
      size: Vector2(100, 56),
      style: surfaceStyle,
    ),
    RoomHazardComponent(
      position: Vector2(690, 708),
      size: Vector2(100, 12),
      style: RoomHazardStyle.spikes,
      surfaceStyle: surfaceStyle,
      sourceId: 'hazard.collision-archive.room3-1.compression-teeth',
    ),
    RoomHazardComponent(
      position: Vector2(2520, 778),
      size: Vector2(100, 12),
      style: RoomHazardStyle.spikes,
      surfaceStyle: surfaceStyle,
      sourceId: 'hazard.collision-archive.room3-3.polarity-teeth',
    ),
    PulsingLaserComponent(
      position: Vector2(1550, 640),
      size: Vector2(14, 384),
      sourceId: 'hazard.collision-archive.room3-2.vector-slice',
      style: surfaceStyle,
    ),
    PulsingLaserComponent(
      position: Vector2(2740, 680),
      size: Vector2(14, 344),
      sourceId: 'hazard.collision-archive.room3-3.merge-beam',
      style: surfaceStyle,
      phaseOffset: 1.2,
    ),
    CrusherHazardComponent(
      start: Vector2(2160, 430),
      end: Vector2(2160, 760),
      size: Vector2(95, 65),
      sourceId: 'hazard.collision-archive.room3-3.polarity-crusher',
      style: surfaceStyle,
      periodSeconds: 3.4,
    ),
    JumpPadComponent(position: Vector2(520, 1012), style: surfaceStyle),
    JumpPadComponent(position: Vector2(1440, 1012), style: surfaceStyle),
    JumpPadComponent(position: Vector2(2420, 1012), style: surfaceStyle),
    CheckpointBeaconComponent(
      position: Vector2(1015, 1024),
      index: 1,
      style: surfaceStyle,
      onActivated: onCheckpointActivated,
    ),
    CheckpointBeaconComponent(
      position: Vector2(1975, 1024),
      index: 2,
      style: surfaceStyle,
      onActivated: onCheckpointActivated,
    ),
    CheckpointBeaconComponent(
      position: Vector2(2935, 1024),
      index: 3,
      style: surfaceStyle,
      onActivated: onCheckpointActivated,
    ),
  ];

  bool tryMerge(CrawlerComponent first, CrawlerComponent second) => false;

  @override
  void openPatchSelection() => game.openRoomThreePatchSelection();
}
