import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/rooms/four_cell_chapter_controller.dart';

final class RoomTwoController extends FourCellChapterController {
  RoomTwoController({required super.progress});

  @override
  PlatformSurfaceStyle get surfaceStyle => PlatformSurfaceStyle.temporal;

  @override
  RoomBackdropStyle get backdropStyle => RoomBackdropStyle.temporal;

  @override
  CampaignChapterBossKind get bossKind => CampaignChapterBossKind.chronoJailer;

  @override
  RunItemId get questRewardItem => RunItemId.echoClock;

  @override
  RunItemId get bossRewardItem => RunItemId.temporalRelay;

  @override
  String get recordLocalizationKey => 'quest.timeFragment';

  @override
  String get bossIntroLocalizationKey => 'boss.chronoJailer.intro';

  @override
  Color get chapterAccentColor => const Color(0xFF9D8CFF);

  int get activatedTerminalCount => recordCount;

  @override
  List<ChapterEnemySpawn> get enemySpawns => const <ChapterEnemySpawn>[
    ChapterEnemySpawn(0, PlatformerEnemyArchetype.tickRunner, 300, 972),
    ChapterEnemySpawn(0, PlatformerEnemyArchetype.echoBat, 700, 720),
    ChapterEnemySpawn(1, PlatformerEnemyArchetype.delaySniper, 1160, 840),
    ChapterEnemySpawn(1, PlatformerEnemyArchetype.tickRunner, 1740, 972),
    ChapterEnemySpawn(2, PlatformerEnemyArchetype.rewindSkater, 2100, 862),
    ChapterEnemySpawn(2, PlatformerEnemyArchetype.echoBat, 2700, 780),
  ];

  @override
  List<PlatformSurfaceComponent> buildChapterSurfaces() =>
      <PlatformSurfaceComponent>[
        surface(0, 0, 24, 1080, boundary: true),
        surface(worldSize.x - 24, 0, 24, 1080, boundary: true),
        // ROOM 2-1: clockwork ascent.
        surface(0, 1024, 400, 56),
        surface(500, 1024, 460, 56),
        surface(100, 900, 190, 22),
        surface(310, 810, 180, 22),
        surface(650, 720, 190, 22),
        MovingPlatformComponent(
          start: Vector2(450, 910),
          end: Vector2(570, 700),
          size: Vector2(120, 22),
          periodSeconds: 4,
          style: surfaceStyle,
        ),
        // ROOM 2-2: broken timeline.
        surface(960, 1024, 360, 56),
        surface(1420, 1024, 500, 56),
        surface(1040, 880, 210, 22),
        surface(1490, 790, 190, 22),
        surface(1700, 700, 170, 22),
        BreakablePlatformComponent(
          position: Vector2(1300, 720),
          size: Vector2(150, 22),
          style: surfaceStyle,
        ),
        // ROOM 2-3: rewind pendulum chamber.
        surface(1920, 1024, 380, 56),
        surface(2400, 1024, 480, 56),
        surface(2010, 900, 200, 22),
        surface(2500, 790, 190, 22),
        surface(2690, 700, 150, 22),
        MovingPlatformComponent(
          start: Vector2(2250, 900),
          end: Vector2(2400, 690),
          size: Vector2(125, 22),
          periodSeconds: 3.5,
          style: surfaceStyle,
        ),
        // Boss cell.
        surface(2880, 1024, 960, 56),
        surface(3070, 850, 180, 22),
        surface(3530, 850, 180, 22),
      ];

  @override
  List<Component> buildChapterFeatures() => <Component>[
    DamagePitComponent(
      position: Vector2(400, 1024),
      size: Vector2(100, 56),
      style: surfaceStyle,
    ),
    DamagePitComponent(
      position: Vector2(1320, 1024),
      size: Vector2(100, 56),
      style: surfaceStyle,
    ),
    DamagePitComponent(
      position: Vector2(2300, 1024),
      size: Vector2(100, 56),
      style: surfaceStyle,
    ),
    RoomHazardComponent(
      position: Vector2(680, 708),
      size: Vector2(100, 12),
      style: RoomHazardStyle.spikes,
      surfaceStyle: surfaceStyle,
      sourceId: 'hazard.temporal-hall.room2-1.clock-teeth',
    ),
    RoomHazardComponent(
      position: Vector2(2520, 778),
      size: Vector2(100, 12),
      style: RoomHazardStyle.spikes,
      surfaceStyle: surfaceStyle,
      sourceId: 'hazard.temporal-hall.room2-3.rewind-teeth',
    ),
    PulsingLaserComponent(
      position: Vector2(1560, 650),
      size: Vector2(14, 374),
      sourceId: 'hazard.temporal-hall.room2-2.timeline-cut',
      style: surfaceStyle,
      activeSeconds: 1.1,
      inactiveSeconds: 1.3,
    ),
    PulsingLaserComponent(
      position: Vector2(2740, 680),
      size: Vector2(14, 344),
      sourceId: 'hazard.temporal-hall.room2-3.clock-hand',
      style: surfaceStyle,
      phaseOffset: 1.2,
    ),
    CrusherHazardComponent(
      start: Vector2(2170, 430),
      end: Vector2(2170, 760),
      size: Vector2(90, 60),
      sourceId: 'hazard.temporal-hall.room2-3.pendulum',
      style: surfaceStyle,
      periodSeconds: 4.2,
    ),
    JumpPadComponent(position: Vector2(525, 1012), style: surfaceStyle),
    JumpPadComponent(position: Vector2(1450, 1012), style: surfaceStyle),
    JumpPadComponent(position: Vector2(2430, 1012), style: surfaceStyle),
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

  @override
  void openPatchSelection() => game.openRoomTwoPatchSelection();
}
