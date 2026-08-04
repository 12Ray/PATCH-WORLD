import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generated animation sheets match their manifest frame geometry',
    () async {
      final manifestFile = File(
        'assets/images/sprites/animations/manifest.json',
      );
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;

      expect(manifest.keys, {
        'qa-hero-idle',
        'qa-hero-move',
        'qa-hero-pulse',
        'qa-hero-hurt',
        'crawler-chase',
        'crawler-heal',
        'crawler-overflow',
        'phase-hound-run',
        'sentinel-scan',
        'sentinel-fire',
        'sentinel-cooldown',
        'composite-stalk',
        'composite-shockwave',
        'optimizer-analyze',
        'optimizer-predict',
        'optimizer-perfect',
        'optimizer-overflow',
      });

      for (final entry in manifest.entries) {
        final metadata = entry.value as Map<String, dynamic>;
        final frameSize = (metadata['frameSize'] as List<dynamic>).cast<int>();
        final frameCount = metadata['frames'] as int;
        final validation = metadata['validation'] as Map<String, dynamic>;
        final asset = metadata['asset'] as String;
        final bytes = await File('assets/$asset').readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;

        expect(image.width, frameSize.first * frameCount, reason: entry.key);
        expect(image.height, frameSize.last, reason: entry.key);
        expect(validation['transparentCorners'], isTrue, reason: entry.key);
        expect((validation['baseline'] as List<dynamic>).toSet(), {246});
        expect((validation['centroidX'] as List<dynamic>).length, frameCount);

        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(pixels, isNotNull, reason: entry.key);
        final lastPixel = (image.width * image.height - 1) * 4;
        expect(pixels!.getUint8(3), 0, reason: '${entry.key} top-left');
        expect(
          pixels.getUint8(lastPixel + 3),
          0,
          reason: '${entry.key} bottom-right',
        );

        if (entry.key == 'phase-hound-run') {
          expect(frameCount, 6);
          final centroids = (validation['centroidX'] as List<dynamic>)
              .cast<num>();
          final xs = centroids.map((value) => value.toDouble()).toList();
          expect(
            xs.reduce((a, b) => a < b ? a : b),
            greaterThanOrEqualTo(127.5),
          );
          expect(xs.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(128.5));
          final coverage = (validation['alphaCoverage'] as List<dynamic>)
              .cast<num>();
          expect(coverage.every((value) => value >= 0.1), isTrue);
        }
      }
    },
  );

  test('Phase Hound uses its dedicated animation sheet', () async {
    final source = await File(
      'lib/game/components/enemies/phase_hound_component.dart',
    ).readAsString();

    expect(source, contains('sprites/animations/phase-hound-run.png'));
    expect(source, isNot(contains('sprites/crawler.png')));
    expect(source, isNot(contains('sprites/animations/crawler-chase.png')));
  });
}
