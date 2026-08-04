import 'package:flutter/foundation.dart';
import 'package:patch_world/game/systems/frame_burst_controller.dart';

@immutable
final class UiSnapshot {
  const UiSnapshot({
    required this.integrity,
    required this.maxIntegrity,
    required this.roomLabel,
    required this.anomalyLabel,
    required this.objectiveLabel,
    required this.selectedPatchIds,
    this.normalizedHeat,
    this.echoPulseCount,
    this.frameBurstPhase,
    this.frameBurstProgress,
    this.bossHealth,
    this.bossMaxHealth,
    this.bossStability,
    this.patternConfidence,
    this.bossPhase,
    this.survivalLevel,
    this.survivalExperience,
    this.survivalExperienceToNext,
    this.survivalCombo,
    this.survivalOverclock = false,
    this.survivalDataCharge,
    this.survivalDataSurge = false,
    this.survivalFusionCount = 0,
    this.motionVentReady = false,
  });

  factory UiSnapshot.initial() => const UiSnapshot(
    integrity: 5,
    maxIntegrity: 5,
    roomLabel: 'BOOT',
    anomalyLabel: '',
    objectiveLabel: '',
    selectedPatchIds: <String>[],
  );

  final int integrity;
  final int maxIntegrity;
  final String roomLabel;
  final String anomalyLabel;
  final String objectiveLabel;
  final List<String> selectedPatchIds;
  final double? normalizedHeat;
  final int? echoPulseCount;
  final FrameBurstPhase? frameBurstPhase;
  final double? frameBurstProgress;
  final int? bossHealth;
  final int? bossMaxHealth;
  final int? bossStability;
  final double? patternConfidence;
  final String? bossPhase;
  final int? survivalLevel;
  final int? survivalExperience;
  final int? survivalExperienceToNext;
  final int? survivalCombo;
  final bool survivalOverclock;
  final int? survivalDataCharge;
  final bool survivalDataSurge;
  final int survivalFusionCount;
  final bool motionVentReady;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiSnapshot &&
          integrity == other.integrity &&
          maxIntegrity == other.maxIntegrity &&
          roomLabel == other.roomLabel &&
          anomalyLabel == other.anomalyLabel &&
          objectiveLabel == other.objectiveLabel &&
          listEquals(selectedPatchIds, other.selectedPatchIds) &&
          normalizedHeat == other.normalizedHeat &&
          echoPulseCount == other.echoPulseCount &&
          frameBurstPhase == other.frameBurstPhase &&
          frameBurstProgress == other.frameBurstProgress &&
          bossHealth == other.bossHealth &&
          bossMaxHealth == other.bossMaxHealth &&
          bossStability == other.bossStability &&
          patternConfidence == other.patternConfidence &&
          bossPhase == other.bossPhase &&
          survivalLevel == other.survivalLevel &&
          survivalExperience == other.survivalExperience &&
          survivalExperienceToNext == other.survivalExperienceToNext &&
          survivalCombo == other.survivalCombo &&
          survivalOverclock == other.survivalOverclock &&
          survivalDataCharge == other.survivalDataCharge &&
          survivalDataSurge == other.survivalDataSurge &&
          survivalFusionCount == other.survivalFusionCount &&
          motionVentReady == other.motionVentReady;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    integrity,
    maxIntegrity,
    roomLabel,
    anomalyLabel,
    objectiveLabel,
    Object.hashAll(selectedPatchIds),
    normalizedHeat,
    echoPulseCount,
    frameBurstPhase,
    frameBurstProgress,
    bossHealth,
    bossMaxHealth,
    bossStability,
    patternConfidence,
    bossPhase,
    survivalLevel,
    survivalExperience,
    survivalExperienceToNext,
    survivalCombo,
    survivalOverclock,
    survivalDataCharge,
    survivalDataSurge,
    survivalFusionCount,
    motionVentReady,
  ]);
}
