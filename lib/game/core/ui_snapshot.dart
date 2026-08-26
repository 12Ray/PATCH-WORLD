import 'package:flutter/foundation.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
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
    this.selectedWeapon,
    this.dashCooldownRemaining = 0,
    this.airJumpsRemaining = 0,
    this.specialAbilityReady = false,
    this.gauntletChargeSeconds = 0,
    this.gunLaserRemaining = 0,
    this.specialAbilityCooldownRemaining = 0,
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
    this.survivalComboProgress = 0,
    this.survivalCriticalFlowRemaining = 0,
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
  final PlayerWeapon? selectedWeapon;
  final double dashCooldownRemaining;
  final int airJumpsRemaining;
  final bool specialAbilityReady;
  final double gauntletChargeSeconds;
  final double gunLaserRemaining;
  final double specialAbilityCooldownRemaining;
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
  final double survivalComboProgress;
  final double survivalCriticalFlowRemaining;
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
          selectedWeapon == other.selectedWeapon &&
          dashCooldownRemaining == other.dashCooldownRemaining &&
          airJumpsRemaining == other.airJumpsRemaining &&
          specialAbilityReady == other.specialAbilityReady &&
          gauntletChargeSeconds == other.gauntletChargeSeconds &&
          gunLaserRemaining == other.gunLaserRemaining &&
          specialAbilityCooldownRemaining ==
              other.specialAbilityCooldownRemaining &&
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
          survivalComboProgress == other.survivalComboProgress &&
          survivalCriticalFlowRemaining ==
              other.survivalCriticalFlowRemaining &&
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
    selectedWeapon,
    dashCooldownRemaining,
    airJumpsRemaining,
    specialAbilityReady,
    gauntletChargeSeconds,
    gunLaserRemaining,
    specialAbilityCooldownRemaining,
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
    survivalComboProgress,
    survivalCriticalFlowRemaining,
    survivalOverclock,
    survivalDataCharge,
    survivalDataSurge,
    survivalFusionCount,
    motionVentReady,
  ]);
}
