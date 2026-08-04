final class StabilityState {
  static const int perfectStart = 75;
  static const int overflowThreshold = 150;
  static const int healingUnit = 20;

  int current = perfectStart;
  bool get isOverflowed => current >= overflowThreshold;

  void addHealingUnit(int amount) {
    if (amount <= 0 || isOverflowed) return;
    current = (current + amount * healingUnit).clamp(0, overflowThreshold);
  }

  void resetPerfectPhase() => current = perfectStart;
}
