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
      }
    },
  );
}
