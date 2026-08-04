import 'package:flutter/foundation.dart';
import 'package:patch_world/game/systems/frame_burst_controller.dart';

@immutable
final class UiSnapshot {
  const UiSnapshot({
    required this.integrity,
    required this.maxIntegrity,
    required this.roomLabel,
    required this.anomalyLabel,
    required this.selectedPatchIds,
    this.normalizedHeat,
    this.echoPulseCount,
    this.frameBurstPhase,
    this.frameBurstProgress,
  });

  factory UiSnapshot.initial() => const UiSnapshot(
    integrity: 5,
    maxIntegrity: 5,
    roomLabel: 'BOOT',
    anomalyLabel: '',
    selectedPatchIds: <String>[],
  );

  final int integrity;
  final int maxIntegrity;
  final String roomLabel;
  final String anomalyLabel;
  final List<String> selectedPatchIds;
  final double? normalizedHeat;
  final int? echoPulseCount;
  final FrameBurstPhase? frameBurstPhase;
  final double? frameBurstProgress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiSnapshot &&
          integrity == other.integrity &&
          maxIntegrity == other.maxIntegrity &&
          roomLabel == other.roomLabel &&
          anomalyLabel == other.anomalyLabel &&
          listEquals(selectedPatchIds, other.selectedPatchIds) &&
          normalizedHeat == other.normalizedHeat &&
          echoPulseCount == other.echoPulseCount &&
          frameBurstPhase == other.frameBurstPhase &&
          frameBurstProgress == other.frameBurstProgress;

  @override
  int get hashCode => Object.hash(
    integrity,
    maxIntegrity,
    roomLabel,
    anomalyLabel,
    Object.hashAll(selectedPatchIds),
    normalizedHeat,
    echoPulseCount,
    frameBurstPhase,
    frameBurstProgress,
  );
}
