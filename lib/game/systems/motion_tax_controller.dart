final class MotionTaxUpdate {
  const MotionTaxUpdate({required this.heat, required this.didOverheat});

  final double heat;
  final bool didOverheat;
}

final class MotionTaxController {
  MotionTaxController({
    this.heatGainPerSecond = 12,
    this.coolingPerSecond = 30,
    this.maximumHeat = 100,
    this.heatAfterOverheat = 40,
  });

  final double heatGainPerSecond;
  final double coolingPerSecond;
  final double maximumHeat;
  final double heatAfterOverheat;
  double _heat = 0;

  double get heat => _heat;
  double get normalizedHeat => (_heat / maximumHeat).clamp(0, 1);

  MotionTaxUpdate update({required double dt, required bool isMoving}) {
    if (dt <= 0) {
      return MotionTaxUpdate(heat: _heat, didOverheat: false);
    }
    _heat += (isMoving ? heatGainPerSecond : -coolingPerSecond) * dt;
    _heat = _heat.clamp(0, maximumHeat);
    if (_heat < maximumHeat) {
      return MotionTaxUpdate(heat: _heat, didOverheat: false);
    }
    _heat = heatAfterOverheat;
    return MotionTaxUpdate(heat: _heat, didOverheat: true);
  }

  void reset() => _heat = 0;
}
