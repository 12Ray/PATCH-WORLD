import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum FramePacingTarget {
  windows(medianLimitMs: 17.5, p95LimitMs: 16.7),
  web(medianLimitMs: 34, p95LimitMs: 33.4);

  const FramePacingTarget({
    required this.medianLimitMs,
    required this.p95LimitMs,
  });

  final double medianLimitMs;
  final double p95LimitMs;
}

final class FramePacingSummary {
  const FramePacingSummary({
    required this.sampleCount,
    required this.medianMs,
    required this.p95Ms,
    required this.severeFramePercent,
  });

  factory FramePacingSummary.fromMilliseconds(List<double> samples) {
    if (samples.isEmpty) {
      return const FramePacingSummary(
        sampleCount: 0,
        medianMs: 0,
        p95Ms: 0,
        severeFramePercent: 0,
      );
    }
    final sorted = List<double>.of(samples)..sort();
    double percentile(double ratio) =>
        sorted[((sorted.length - 1) * ratio).round()];
    final severeCount = sorted.where((value) => value > 33.4).length;
    return FramePacingSummary(
      sampleCount: sorted.length,
      medianMs: percentile(.5),
      p95Ms: percentile(.95),
      severeFramePercent: severeCount / sorted.length * 100,
    );
  }

  final int sampleCount;
  final double medianMs;
  final double p95Ms;
  final double severeFramePercent;

  double get medianFps => medianMs <= 0 ? 0 : 1000 / medianMs;

  bool passesTarget(FramePacingTarget target) =>
      sampleCount > 0 &&
      medianMs <= target.medianLimitMs &&
      p95Ms <= target.p95LimitMs &&
      severeFramePercent < 1;

  bool get passesReleaseTarget =>
      passesTarget(kIsWeb ? FramePacingTarget.web : FramePacingTarget.windows);
}

/// Opt-in runtime probe for release/profile browser QA.
///
/// Enable with `--dart-define=FRAME_PACING_QA=true`. Normal release builds
/// compile the widget out through the constant guard in [PatchWorldApp].
final class FramePacingProbe extends StatefulWidget {
  const FramePacingProbe({super.key});

  static const bool enabled = bool.fromEnvironment(
    'FRAME_PACING_QA',
    defaultValue: false,
  );
  static const double warmUpSeconds = 2;
  static const double acceptanceSeconds = 30;

  @override
  State<FramePacingProbe> createState() => _FramePacingProbeState();
}

final class _FramePacingProbeState extends State<FramePacingProbe>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<double> _samples = <double>[];
  Duration? _previousElapsed;
  double _lastUiUpdateSeconds = -1;
  double _sampledSeconds = 0;
  bool _resultReported = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final previous = _previousElapsed;
    _previousElapsed = elapsed;
    final elapsedSeconds = elapsed.inMicroseconds / 1000000;
    if (previous == null || elapsedSeconds < FramePacingProbe.warmUpSeconds) {
      return;
    }
    final intervalMs = (elapsed - previous).inMicroseconds.toDouble() / 1000;
    if (intervalMs > 0) _samples.add(intervalMs);
    _sampledSeconds = elapsedSeconds - FramePacingProbe.warmUpSeconds;
    if (!_resultReported &&
        _sampledSeconds >= FramePacingProbe.acceptanceSeconds) {
      _resultReported = true;
      final summary = FramePacingSummary.fromMilliseconds(_samples);
      final target = kIsWeb ? FramePacingTarget.web : FramePacingTarget.windows;
      debugPrint(
        'FRAME_QA_RESULT ${target.name.toUpperCase()} '
        '${summary.passesTarget(target) ? 'PASS' : 'FAIL'} '
        'N=${summary.sampleCount} '
        'MED=${summary.medianMs.toStringAsFixed(2)}ms '
        'P95=${summary.p95Ms.toStringAsFixed(2)}ms '
        '>33.4=${summary.severeFramePercent.toStringAsFixed(2)}%',
      );
    }
    if (_sampledSeconds - _lastUiUpdateSeconds >= .5 && mounted) {
      _lastUiUpdateSeconds = _sampledSeconds;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = FramePacingSummary.fromMilliseconds(_samples);
    final target = kIsWeb ? FramePacingTarget.web : FramePacingTarget.windows;
    final passesTarget = summary.passesTarget(target);
    final complete = _sampledSeconds >= FramePacingProbe.acceptanceSeconds;
    final status = !complete
        ? 'WARM ${_sampledSeconds.clamp(0, 30).toStringAsFixed(1)}/30s'
        : passesTarget
        ? 'PASS'
        : 'FAIL';
    final label =
        'FRAME_QA ${target.name.toUpperCase()} $status | '
        'N=${summary.sampleCount} | '
        'FPS=${summary.medianFps.toStringAsFixed(1)} | '
        'MED=${summary.medianMs.toStringAsFixed(2)}ms | '
        'P95=${summary.p95Ms.toStringAsFixed(2)}ms | '
        '>33.4=${summary.severeFramePercent.toStringAsFixed(2)}%';

    return IgnorePointer(
      child: Semantics(
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6080C18),
            border: Border.all(
              color: complete && passesTarget
                  ? const Color(0xFF45F3A6)
                  : const Color(0xFFFFD35A),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PatchWorldCJK',
                color: Color(0xFFF4F7FF),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
