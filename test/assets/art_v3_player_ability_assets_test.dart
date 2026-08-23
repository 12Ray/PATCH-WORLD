import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Art v3 ability strips keep body size and pivot registered', () async {
    const heroDirectory = 'assets/images/sprites/art_v3/hero';
    const abilityDirectory = 'assets/images/sprites/abilities';
    final manifest =
        jsonDecode(File('$heroDirectory/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final abilities = manifest['abilities'] as Map<String, dynamic>;

    expect(abilities.keys.toSet(), <String>{'sword', 'gauntlet', 'gun'});
    for (final weaponEntry in abilities.entries) {
      final sequence = weaponEntry.value as Map<String, dynamic>;
      final reason = '${weaponEntry.key}.ability';
      final mode = sequence['registrationMode'] as String;
      final transforms = sequence['frameTransforms'] as List<dynamic>;
      final landmarks = sequence['bodyLandmarks'] as List<dynamic>;
      final reference = sequence['idleBodyReference'] as Map<String, dynamic>;

      expect(sequence['state'], 'ability', reason: reason);
      expect(sequence['frames'], 6, reason: reason);
      expect(sequence['displaySize'], <num>[46, 46], reason: reason);
      expect(sequence['baseline'], .9375, reason: reason);
      expect(
        sequence['registrationVersion'],
        'art-v3-ability-root-v1-2026-08-23',
        reason: reason,
      );
      expect(
        mode,
        weaponEntry.key == 'gauntlet' ? 'airborne-center' : 'grounded-root',
        reason: reason,
      );
      expect(transforms, hasLength(6), reason: reason);
      expect(landmarks, hasLength(6), reason: reason);

      final referencePoint =
          (reference[mode == 'airborne-center' ? 'center' : 'root']
              as List<dynamic>);
      final targetX = ((referencePoint[0] as num).toDouble() - 128) * 46 / 256;
      final targetY = ((referencePoint[1] as num).toDouble() - 128) * 46 / 256;
      final referenceBodySize = math.sqrt(
        (reference['pixelCount'] as num).toDouble(),
      );
      double? previousScale;
      for (var frame = 0; frame < 6; frame += 1) {
        final transform = transforms[frame] as Map<String, dynamic>;
        final landmark = landmarks[frame] as Map<String, dynamic>;
        final point =
            (landmark[mode == 'airborne-center' ? 'center' : 'root']
                as List<dynamic>);
        final scale = (transform['scale'] as num).toDouble();
        final registeredX =
            ((point[0] as num).toDouble() - 128) * 46 / 256 * scale +
            (transform['dx'] as num).toDouble();
        final registeredY =
            ((point[1] as num).toDouble() - 128) * 46 / 256 * scale +
            (transform['dy'] as num).toDouble();
        final renderedBodySize =
            math.sqrt((landmark['pixelCount'] as num).toDouble()) * scale;

        expect(scale.isFinite, isTrue, reason: '$reason frame $frame');
        expect(
          scale,
          inInclusiveRange(1.0, 2.6),
          reason: '$reason frame $frame',
        );
        expect(registeredX, closeTo(targetX, .002), reason: reason);
        expect(registeredY, closeTo(targetY, .002), reason: reason);
        expect(
          renderedBodySize,
          closeTo(referenceBodySize, .001),
          reason: '$reason frame $frame',
        );
        if (previousScale != null) {
          expect(
            math.max(scale, previousScale) / math.min(scale, previousScale),
            lessThan(1.5),
            reason: '$reason frame $frame',
          );
        }
        previousScale = scale;
      }

      final bytes = File(
        '$abilityDirectory/${sequence['asset']}',
      ).readAsBytesSync();
      final codec = await instantiateImageCodec(bytes);
      final decoded = await codec.getNextFrame();
      final image = decoded.image;
      expect(image.width, 1536, reason: reason);
      expect(image.height, 256, reason: reason);
      final data = await image.toByteData(format: ImageByteFormat.rawRgba);
      expect(data, isNotNull, reason: reason);
      final rgba = data!.buffer.asUint8List();
      final fingerprints = <int>{};
      for (var frame = 0; frame < 6; frame += 1) {
        var visible = 0;
        var fingerprint = 17;
        for (var y = 0; y < 256; y += 1) {
          for (var x = 0; x < 256; x += 1) {
            final pixel = (y * image.width + frame * 256 + x) * 4;
            if (rgba[pixel + 3] > 16) visible += 1;
            fingerprint =
                0x1fffffff & (fingerprint * 31 + rgba[pixel] + rgba[pixel + 3]);
          }
        }
        expect(
          visible / (256 * 256),
          inInclusiveRange(.04, .42),
          reason: '$reason frame $frame',
        );
        fingerprints.add(fingerprint);
      }
      expect(fingerprints, hasLength(6), reason: reason);
      image.dispose();
      codec.dispose();
    }
  });
}
