import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/survival_anomaly_component.dart';

void main() {
  test(
    'three survival enemies own complete eight-frame art contracts',
    () async {
      const directory = 'assets/images/sprites/survival_v1/enemies';
      final manifest =
          jsonDecode(File('$directory/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final enemies = manifest['enemies'] as Map<String, dynamic>;

      expect(manifest['frameWidth'], 256);
      expect(manifest['frameHeight'], 256);
      expect(manifest['framesPerEnemy'], 8);
      expect(manifest['frameRoles'], <String>[
        'idle',
        'locomotionA',
        'locomotionB',
        'movementAccent',
        'telegraph',
        'active',
        'hurtRecovery',
        'death',
      ]);
      expect(
        enemies.keys.toSet(),
        SurvivalAnomalyKind.values.map((kind) => kind.name).toSet(),
      );

      for (final kind in SurvivalAnomalyKind.values) {
        final spec = enemies[kind.name] as Map<String, dynamic>;
        expect(
          kind.spriteAssetPath,
          'sprites/survival_v1/enemies/${spec['asset']}',
        );
        expect(kind.attackTelegraphSeconds, greaterThanOrEqualTo(.45));
        expect(spec['combatIdentity'], isNotEmpty);
        await _expectEightFrameStrip('$directory/${spec['asset']}', kind.name);
      }
    },
  );
}

Future<void> _expectEightFrameStrip(String path, String reason) async {
  final codec = await instantiateImageCodec(File(path).readAsBytesSync());
  final decoded = await codec.getNextFrame();
  final image = decoded.image;
  expect(image.width, 2048, reason: reason);
  expect(image.height, 256, reason: reason);
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  expect(data, isNotNull, reason: reason);
  final rgba = data!.buffer.asUint8List();
  expect(rgba[3], 0, reason: '$reason transparent corner');

  final fingerprints = <int>{};
  for (var frame = 0; frame < 8; frame += 1) {
    var visible = 0;
    var fingerprint = 17;
    for (var y = 0; y < 256; y += 1) {
      for (var x = 0; x < 256; x += 1) {
        final pixel = (y * image.width + frame * 256 + x) * 4;
        final alpha = rgba[pixel + 3];
        if (alpha > 16) visible += 1;
        fingerprint = 0x1fffffff & (fingerprint * 31 + rgba[pixel] + alpha);
      }
    }
    expect(
      visible / (256 * 256),
      inInclusiveRange(.015, .55),
      reason: '$reason frame $frame',
    );
    fingerprints.add(fingerprint);
  }
  expect(fingerprints, hasLength(8), reason: reason);
  image.dispose();
  codec.dispose();
}
