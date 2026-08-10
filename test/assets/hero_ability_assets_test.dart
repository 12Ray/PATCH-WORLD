import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hero ability manifest points to six-frame transparent strips',
    () async {
      final directory = Directory('assets/images/sprites/abilities');
      final manifest =
          jsonDecode(File('${directory.path}/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final sequences = manifest['sequences'] as Map<String, dynamic>;

      expect(sequences, hasLength(3));
      expect(manifest['frameWidth'], 256);
      expect(manifest['frameHeight'], 256);
      for (final sequence in sequences.values.cast<Map<String, dynamic>>()) {
        expect(sequence['frames'], 6);
        final bytes = File(
          '${directory.path}/${sequence['asset']}',
        ).readAsBytesSync();
        final codec = await instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1536);
        expect(frame.image.height, 256);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test('generated gameplay SFX are valid non-empty PCM wave files', () {
    for (final name in <String>[
      'jump.wav',
      'double_jump.wav',
      'land.wav',
      'sword_slash.wav',
      'sword_dash.wav',
      'gauntlet_hit.wav',
      'gun_shot.wav',
      'gun_rail.wav',
      'platform_break.wav',
      'jump_pad.wav',
      'laser_fire.wav',
      'crusher_impact.wav',
      'checkpoint.wav',
      'enemy_melee.wav',
      'enemy_projectile.wav',
      'enemy_field.wav',
      'enemy_boss.wav',
    ]) {
      final bytes = File('assets/audio/sfx/$name').readAsBytesSync();
      expect(bytes.length, greaterThan(2048), reason: name);
      expect(utf8.decode(bytes.take(4).toList()), 'RIFF', reason: name);
      expect(utf8.decode(bytes.skip(8).take(4).toList()), 'WAVE', reason: name);
    }
  });
}
