import 'package:flame/components.dart';

abstract final class SurvivalNexusLayout {
  static const double worldWidth = 2880;
  static const double worldHeight = 1620;
  static const double centerX = worldWidth / 2;
  static const double centerY = worldHeight / 2;
  static const double regionInnerX = 1080;
  static const double regionOuterX = worldWidth - regionInnerX;
  static const double regionInnerY = 650;
  static const double regionOuterY = worldHeight - regionInnerY;

  static Vector2 get center => Vector2(centerX, centerY);
}

enum SurvivalNexusRegion {
  dataFoundry,
  temporalBreach,
  collisionGraveyard,
  reactorYard,
}

extension SurvivalNexusRegionSpec on SurvivalNexusRegion {
  String get id => switch (this) {
    SurvivalNexusRegion.dataFoundry => 'dataFoundry',
    SurvivalNexusRegion.temporalBreach => 'temporalBreach',
    SurvivalNexusRegion.collisionGraveyard => 'collisionGraveyard',
    SurvivalNexusRegion.reactorYard => 'reactorYard',
  };

  String get localizationKey => 'survivalRegion.$id';

  Vector2 get objectivePosition => switch (this) {
    SurvivalNexusRegion.dataFoundry => Vector2(480, 360),
    SurvivalNexusRegion.temporalBreach => Vector2(2400, 360),
    SurvivalNexusRegion.collisionGraveyard => Vector2(480, 1260),
    SurvivalNexusRegion.reactorYard => Vector2(2400, 1260),
  };

  Vector2 get escortTarget => switch (this) {
    SurvivalNexusRegion.dataFoundry => Vector2(1120, 660),
    SurvivalNexusRegion.temporalBreach => Vector2(1760, 660),
    SurvivalNexusRegion.collisionGraveyard => Vector2(1120, 960),
    SurvivalNexusRegion.reactorYard => Vector2(1760, 960),
  };

  static SurvivalNexusRegion? forPosition(Vector2 position) {
    if (position.x <= SurvivalNexusLayout.regionInnerX &&
        position.y <= SurvivalNexusLayout.regionInnerY) {
      return SurvivalNexusRegion.dataFoundry;
    }
    if (position.x >= SurvivalNexusLayout.regionOuterX &&
        position.y <= SurvivalNexusLayout.regionInnerY) {
      return SurvivalNexusRegion.temporalBreach;
    }
    if (position.x <= SurvivalNexusLayout.regionInnerX &&
        position.y >= SurvivalNexusLayout.regionOuterY) {
      return SurvivalNexusRegion.collisionGraveyard;
    }
    if (position.x >= SurvivalNexusLayout.regionOuterX &&
        position.y >= SurvivalNexusLayout.regionOuterY) {
      return SurvivalNexusRegion.reactorYard;
    }
    return null;
  }
}

enum SurvivalRegionEventKind { relayRepair, escort, riftSeal, riskCache }

extension SurvivalRegionEventKindSpec on SurvivalRegionEventKind {
  String get id => switch (this) {
    SurvivalRegionEventKind.relayRepair => 'relayRepair',
    SurvivalRegionEventKind.escort => 'escort',
    SurvivalRegionEventKind.riftSeal => 'riftSeal',
    SurvivalRegionEventKind.riskCache => 'riskCache',
  };

  String get objectiveLocalizationKey => 'survivalObjective.$id';
  String get alertLocalizationKey => 'survivalAlert.event.$id';
}

final class SurvivalRegionEventPlan {
  const SurvivalRegionEventPlan({
    required this.startSecond,
    required this.region,
    required this.kind,
    this.durationSeconds = 42,
  });

  final int startSecond;
  final SurvivalNexusRegion region;
  final SurvivalRegionEventKind kind;
  final double durationSeconds;
}

enum SurvivalNexusBossKind {
  foundryOverseer,
  temporalRegent,
  collisionBehemoth,
  nexusCore,
}

extension SurvivalNexusBossKindSpec on SurvivalNexusBossKind {
  String get id => switch (this) {
    SurvivalNexusBossKind.foundryOverseer => 'foundryOverseer',
    SurvivalNexusBossKind.temporalRegent => 'temporalRegent',
    SurvivalNexusBossKind.collisionBehemoth => 'collisionBehemoth',
    SurvivalNexusBossKind.nexusCore => 'nexusCore',
  };

  String get localizationKey => 'survivalBoss.$id';

  int get healthMaximum => switch (this) {
    SurvivalNexusBossKind.foundryOverseer => 28,
    SurvivalNexusBossKind.temporalRegent => 36,
    SurvivalNexusBossKind.collisionBehemoth => 44,
    SurvivalNexusBossKind.nexusCore => 72,
  };

  int get phaseCount => this == SurvivalNexusBossKind.nexusCore ? 3 : 2;

  List<String> patternIdsForPhase(int phase) {
    final safePhase = phase.clamp(1, phaseCount);
    final patterns = switch (safePhase) {
      1 => const <String>['needleFan', 'radialBurst', 'targetGrid'],
      2 => const <String>['crossfire', 'spiralRing', 'collapseChase'],
      _ => const <String>['mirrorVolley', 'orbitStorm', 'nexusJudgment'],
    };
    return patterns.map((pattern) => '$id.$pattern').toList(growable: false);
  }
}

final class SurvivalBossMilestone {
  const SurvivalBossMilestone({required this.second, required this.kind});

  final int second;
  final SurvivalNexusBossKind kind;
}

abstract final class SurvivalPhaseElevenDirector {
  static const List<SurvivalRegionEventPlan> eventSchedule =
      <SurvivalRegionEventPlan>[
        SurvivalRegionEventPlan(
          startSecond: 60,
          region: SurvivalNexusRegion.dataFoundry,
          kind: SurvivalRegionEventKind.relayRepair,
        ),
        SurvivalRegionEventPlan(
          startSecond: 180,
          region: SurvivalNexusRegion.temporalBreach,
          kind: SurvivalRegionEventKind.escort,
        ),
        SurvivalRegionEventPlan(
          startSecond: 360,
          region: SurvivalNexusRegion.collisionGraveyard,
          kind: SurvivalRegionEventKind.riftSeal,
        ),
        SurvivalRegionEventPlan(
          startSecond: 480,
          region: SurvivalNexusRegion.reactorYard,
          kind: SurvivalRegionEventKind.riskCache,
        ),
        SurvivalRegionEventPlan(
          startSecond: 660,
          region: SurvivalNexusRegion.dataFoundry,
          kind: SurvivalRegionEventKind.relayRepair,
        ),
        SurvivalRegionEventPlan(
          startSecond: 780,
          region: SurvivalNexusRegion.temporalBreach,
          kind: SurvivalRegionEventKind.escort,
        ),
        SurvivalRegionEventPlan(
          startSecond: 960,
          region: SurvivalNexusRegion.collisionGraveyard,
          kind: SurvivalRegionEventKind.riftSeal,
        ),
        SurvivalRegionEventPlan(
          startSecond: 1080,
          region: SurvivalNexusRegion.reactorYard,
          kind: SurvivalRegionEventKind.riskCache,
        ),
      ];

  static const List<SurvivalBossMilestone> bossSchedule =
      <SurvivalBossMilestone>[
        SurvivalBossMilestone(
          second: 300,
          kind: SurvivalNexusBossKind.foundryOverseer,
        ),
        SurvivalBossMilestone(
          second: 600,
          kind: SurvivalNexusBossKind.temporalRegent,
        ),
        SurvivalBossMilestone(
          second: 900,
          kind: SurvivalNexusBossKind.collisionBehemoth,
        ),
        SurvivalBossMilestone(
          second: 1200,
          kind: SurvivalNexusBossKind.nexusCore,
        ),
      ];

  static List<SurvivalRegionEventPlan> eventsBetween({
    required int previousSecond,
    required int currentSecond,
  }) => eventSchedule
      .where(
        (event) =>
            previousSecond < event.startSecond &&
            currentSecond >= event.startSecond,
      )
      .toList(growable: false);

  static List<SurvivalBossMilestone> bossesBetween({
    required int previousSecond,
    required int currentSecond,
  }) => bossSchedule
      .where(
        (boss) => previousSecond < boss.second && currentSecond >= boss.second,
      )
      .toList(growable: false);
}
