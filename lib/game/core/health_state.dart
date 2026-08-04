enum HealthMutation { unchanged, damaged, healed, defeated, overflowed }

final class HealthState {
  HealthState({
    required this.max,
    required int current,
    this.overflowMargin = 2,
  }) : assert(max > 0),
       assert(overflowMargin >= 0),
       current = current.clamp(0, max + overflowMargin);

  final int max;
  final int overflowMargin;
  int current;

  int get overflowThreshold => max + overflowMargin;
  bool get isDefeated => current <= 0;
  bool get isOverflowed => current >= overflowThreshold;

  double get normalizedForOverflowBar {
    if (overflowThreshold <= 0) {
      return 0;
    }
    return (current / overflowThreshold).clamp(0, 1).toDouble();
  }

  HealthMutation applyDamage(int amount) {
    if (amount <= 0 || isDefeated) {
      return HealthMutation.unchanged;
    }
    current = (current - amount).clamp(0, overflowThreshold);
    return current == 0 ? HealthMutation.defeated : HealthMutation.damaged;
  }

  HealthMutation applyHealing(int amount) {
    if (amount <= 0 || isDefeated || isOverflowed) {
      return HealthMutation.unchanged;
    }
    current = (current + amount).clamp(0, overflowThreshold);
    return isOverflowed ? HealthMutation.overflowed : HealthMutation.healed;
  }
}
