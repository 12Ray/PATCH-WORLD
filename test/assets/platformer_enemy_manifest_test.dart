import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all fifteen platformer enemy strips are valid RGBA atlases', () async {
    final manifest =
        jsonDecode(
              await File(
                'assets/images/sprites/platformer/manifest.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final assets = manifest['assets'] as Map<String, dynamic>;
    expect(assets, hasLength(15));
    for (final entry in assets.entries) {
      final bytes = await File(
        'assets/images/sprites/platformer/${entry.value}',
      ).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1024, reason: entry.key);
      expect(image.height, 256, reason: entry.key);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(pixels, isNotNull, reason: entry.key);
      expect(pixels!.getUint8(3), 0, reason: '${entry.key} top-left alpha');
    }
  });
}
