import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/frame_pacing_probe.dart';

void main() {
  test('60 Hz frame samples pass the release target', () {
    final summary = FramePacingSummary.fromMilliseconds(
      List<double>.filled(1800, 16.667),
    );

    expect(summary.sampleCount, 1800);
    expect(summary.medianFps, closeTo(60, .1));
    expect(summary.medianMs, closeTo(16.667, .001));
    expect(summary.p95Ms, closeTo(16.667, .001));
    expect(summary.severeFramePercent, 0);
    expect(summary.passesTarget(FramePacingTarget.windows), isTrue);
    expect(summary.passesTarget(FramePacingTarget.web), isTrue);
  });

  test('30 Hz samples pass Web but fail the Windows 60 Hz target', () {
    final summary = FramePacingSummary.fromMilliseconds(
      List<double>.filled(900, 33.333),
    );

    expect(summary.passesTarget(FramePacingTarget.windows), isFalse);
    expect(summary.passesTarget(FramePacingTarget.web), isTrue);
  });

  test('stutter above the one-percent severe-frame budget fails', () {
    final samples = <double>[
      ...List<double>.filled(980, 16.667),
      ...List<double>.filled(20, 40),
    ];
    final summary = FramePacingSummary.fromMilliseconds(samples);

    expect(summary.severeFramePercent, 2);
    expect(summary.passesTarget(FramePacingTarget.windows), isFalse);
    expect(summary.passesTarget(FramePacingTarget.web), isFalse);
  });
}
