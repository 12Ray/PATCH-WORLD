final class RetaliationEchoController {
  RetaliationEchoController({this.pulsesPerEcho = 4})
    : assert(pulsesPerEcho > 0);

  final int pulsesPerEcho;
  int _pulseCount = 0;

  int get pulseCount => _pulseCount;
  int get remainingPulses => pulsesPerEcho - _pulseCount;

  bool recordPulse() {
    _pulseCount += 1;
    if (_pulseCount < pulsesPerEcho) {
      return false;
    }
    _pulseCount = 0;
    return true;
  }

  void reset() => _pulseCount = 0;
}
