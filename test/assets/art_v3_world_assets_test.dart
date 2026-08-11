import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 15 Art v3 enemies have locomotion and signature frames', () async {
    const directory = 'assets/images/sprites/art_v3/enemies';
    final manifest =
        jsonDecode(File('$directory/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final enemies = manifest['enemies'] as Map<String, dynamic>;

    expect(manifest['version'], 1);
    expect(enemies, hasLength(15));
    expect(
      enemies.values
          .map((entry) => (entry as Map<String, dynamic>)['room'])
          .toSet(),
      <String>{'damageLab', 'temporalHall', 'collisionArchive'},
    );
    for (final entry in enemies.entries) {
      final spec = entry.value as Map<String, dynamic>;
      final signature = spec['signature'] as Map<String, dynamic>;
      expect(spec['frames'], 8, reason: entry.key);
      expect(spec['locomotion'], containsPair('frames', <num>[0, 3]));
      expect(signature['telegraphFrame'], 4, reason: entry.key);
      expect(signature['activeFrame'], 5, reason: entry.key);
      expect(signature['recoveryFrames'], <num>[6, 7], reason: entry.key);
      expect(spec['gameplayContract'], contains('hitbox'));
      await _expectStrip(
        '$directory/${spec['asset']}',
        frames: 8,
        minimumUniqueFrames: 6,
        reason: entry.key,
      );
    }
  });

  test('four room foreground skins retain code geometry ownership', () async {
    const directory = 'assets/images/sprites/art_v3/environment';
    final manifest =
        jsonDecode(File('$directory/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final rooms = manifest['rooms'] as Map<String, dynamic>;
    expect(rooms.keys.toSet(), <String>{
      'damage',
      'temporal',
      'collision',
      'optimizer',
    });
    for (final entry in rooms.entries) {
      final spec = entry.value as Map<String, dynamic>;
      expect(spec['frames'], 4, reason: entry.key);
      expect(spec['roles'], <String>[
        'surface',
        'cornerWall',
        'statePlatform',
        'interactive',
      ]);
      expect(spec['gameplayContract'], contains('code geometry'));
      final bytes = File('$directory/${spec['asset']}').readAsBytesSync();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 384 * 4, reason: entry.key);
      expect(frame.image.height, 256, reason: entry.key);
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('optimizer Art v3 has all four readable phases', () async {
    const directory = 'assets/images/sprites/art_v3/boss';
    final manifest =
        jsonDecode(File('$directory/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final states = manifest['states'] as Map<String, dynamic>;
    expect(states.keys.toSet(), <String>{
      'analyze',
      'predict',
      'perfect',
      'overflow',
    });
    expect((states['predict'] as Map<String, dynamic>)['eventFrame'], 1);
    for (final entry in states.entries) {
      final spec = entry.value as Map<String, dynamic>;
      await _expectStrip(
        '$directory/${spec['asset']}',
        frames: 4,
        minimumUniqueFrames: 4,
        reason: entry.key,
      );
    }
  });
}

Future<void> _expectStrip(
  String path, {
  required int frames,
  required int minimumUniqueFrames,
  required String reason,
}) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await instantiateImageCodec(bytes);
  final decoded = await codec.getNextFrame();
  final image = decoded.image;
  expect(image.width, 256 * frames, reason: reason);
  expect(image.height, 256, reason: reason);
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  expect(data, isNotNull, reason: reason);
  final rgba = data!.buffer.asUint8List();
  final fingerprints = <int>{};
  for (var frame = 0; frame < frames; frame += 1) {
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
      inInclusiveRange(0.015, 0.55),
      reason: '$reason frame $frame',
    );
    fingerprints.add(fingerprint);
  }
  expect(fingerprints.length, greaterThanOrEqualTo(minimumUniqueFrames));
  image.dispose();
  codec.dispose();
}
