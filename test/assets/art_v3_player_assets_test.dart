import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Art v3 weapon idle strips satisfy the Pass 0 contract', () async {
    const directory = 'assets/images/sprites/art_v3/hero';
    final manifest =
        jsonDecode(File('$directory/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final sequences = manifest['sequences'] as Map<String, dynamic>;

    expect(manifest['version'], 3);
    expect(manifest['frameWidth'], 256);
    expect(manifest['frameHeight'], 256);
    expect(sequences.keys.toSet(), <String>{'sword', 'gauntlet', 'gun'});

    final standingSilhouettes = <String, Set<int>>{};

    for (final entry in sequences.entries) {
      final sequence = entry.value as Map<String, dynamic>;
      expect(sequence['state'], 'idle', reason: entry.key);
      expect(sequence['frames'], 4, reason: entry.key);
      expect(sequence['fps'], 6, reason: entry.key);
      expect(sequence['loop'], isTrue, reason: entry.key);
      expect(sequence['pivot'], <num>[0.5, 0.5], reason: entry.key);
      expect(sequence['baseline'], 0.86, reason: entry.key);
      expect(sequence['displaySize'], <num>[54, 54], reason: entry.key);
      expect(sequence['standingFrame'], 0, reason: entry.key);
      expect(sequence['promptVersion'], 'art-v3-pass0-2026-08-11');

      final bytes = File('$directory/${sequence['asset']}').readAsBytesSync();
      final codec = await instantiateImageCodec(bytes);
      final decoded = await codec.getNextFrame();
      final image = decoded.image;
      expect(image.width, 1024, reason: entry.key);
      expect(image.height, 256, reason: entry.key);

      final data = await image.toByteData(format: ImageByteFormat.rawRgba);
      expect(data, isNotNull, reason: entry.key);
      final rgba = data!.buffer.asUint8List();
      final baselines = <int>[];
      final frameFingerprints = <int>{};
      for (var frame = 0; frame < 4; frame += 1) {
        var visible = 0;
        var bottom = -1;
        var fingerprint = 17;
        for (var y = 0; y < 256; y += 1) {
          for (var x = 0; x < 256; x += 1) {
            final pixel = (y * image.width + frame * 256 + x) * 4;
            final alpha = rgba[pixel + 3];
            if (alpha > 16) {
              visible += 1;
              bottom = y;
            }
            fingerprint =
                0x1fffffff & (fingerprint * 31 + rgba[pixel] + rgba[pixel + 3]);
          }
        }
        expect(visible / (256 * 256), inInclusiveRange(0.12, 0.45));
        expect(rgba[(frame * 256) * 4 + 3], 0, reason: entry.key);
        expect(
          rgba[((255 * image.width) + frame * 256 + 255) * 4 + 3],
          0,
          reason: entry.key,
        );
        baselines.add(bottom);
        frameFingerprints.add(fingerprint);
      }
      expect(baselines.toSet(), hasLength(1), reason: entry.key);
      expect(
        baselines.toSet().single,
        inInclusiveRange(238, 240),
        reason: entry.key,
      );
      expect(frameFingerprints, hasLength(4), reason: entry.key);
      standingSilhouettes[entry.key] = _sampleSilhouette(
        rgba: rgba,
        stripWidth: image.width,
        frame: sequence['standingFrame'] as int,
        sourceSize: manifest['frameWidth'] as int,
        displaySize: (sequence['displaySize'] as List<dynamic>).first as int,
      );

      image.dispose();
      codec.dispose();
    }

    final weaponNames = standingSilhouettes.keys.toList(growable: false);
    for (var first = 0; first < weaponNames.length; first += 1) {
      for (var second = first + 1; second < weaponNames.length; second += 1) {
        final firstName = weaponNames[first];
        final secondName = weaponNames[second];
        expect(
          _jaccardDistance(
            standingSilhouettes[firstName]!,
            standingSilhouettes[secondName]!,
          ),
          greaterThanOrEqualTo(0.30),
          reason:
              '$firstName and $secondName must remain distinguishable at the '
              '54x54 gameplay display size',
        );
      }
    }
  });

  test('Art v3 locomotion strips satisfy the Pass 1 contract', () async {
    const directory = 'assets/images/sprites/art_v3/hero';
    final manifest =
        jsonDecode(File('$directory/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final locomotion = manifest['locomotion'] as Map<String, dynamic>;
    const expectedStates = <String, ({int frames, int fps, bool loop})>{
      'run': (frames: 6, fps: 10, loop: true),
      'jumpRise': (frames: 2, fps: 10, loop: true),
      'apex': (frames: 1, fps: 1, loop: true),
      'fall': (frames: 2, fps: 10, loop: true),
      'land': (frames: 3, fps: 12, loop: false),
    };

    expect(locomotion.keys.toSet(), <String>{'sword', 'gauntlet', 'gun'});
    for (final weaponEntry in locomotion.entries) {
      final states = weaponEntry.value as Map<String, dynamic>;
      expect(states.keys.toSet(), expectedStates.keys.toSet());
      for (final stateEntry in states.entries) {
        final contract = expectedStates[stateEntry.key]!;
        final sequence = stateEntry.value as Map<String, dynamic>;
        final reason = '${weaponEntry.key}.${stateEntry.key}';
        expect(sequence['state'], stateEntry.key, reason: reason);
        expect(sequence['frames'], contract.frames, reason: reason);
        expect(sequence['fps'], contract.fps, reason: reason);
        expect(sequence['loop'], contract.loop, reason: reason);
        expect(sequence['pivot'], <num>[0.5, 0.5], reason: reason);
        expect(sequence['baseline'], 0.86, reason: reason);
        expect(sequence['displaySize'], <num>[54, 54], reason: reason);
        expect(sequence['sourceGrid'], <num>[4, 4], reason: reason);
        expect(
          sequence['promptVersion'],
          'art-v3-pass1-2026-08-11',
          reason: reason,
        );

        final bytes = File('$directory/${sequence['asset']}').readAsBytesSync();
        final codec = await instantiateImageCodec(bytes);
        final decoded = await codec.getNextFrame();
        final image = decoded.image;
        expect(image.width, contract.frames * 256, reason: reason);
        expect(image.height, 256, reason: reason);
        final data = await image.toByteData(format: ImageByteFormat.rawRgba);
        expect(data, isNotNull, reason: reason);
        final rgba = data!.buffer.asUint8List();
        final baselines = <int>[];
        final frameFingerprints = <int>{};
        for (var frame = 0; frame < contract.frames; frame += 1) {
          var visible = 0;
          var bottom = -1;
          var fingerprint = 17;
          for (var y = 0; y < 256; y += 1) {
            for (var x = 0; x < 256; x += 1) {
              final pixel = (y * image.width + frame * 256 + x) * 4;
              final alpha = rgba[pixel + 3];
              if (alpha > 16) {
                visible += 1;
                bottom = y;
              }
              fingerprint =
                  0x1fffffff &
                  (fingerprint * 31 + rgba[pixel] + rgba[pixel + 3]);
            }
          }
          expect(
            visible / (256 * 256),
            inInclusiveRange(0.18, 0.40),
            reason: reason,
          );
          expect(rgba[(frame * 256) * 4 + 3], 0, reason: reason);
          expect(
            rgba[((255 * image.width) + frame * 256 + 255) * 4 + 3],
            0,
            reason: reason,
          );
          baselines.add(bottom);
          frameFingerprints.add(fingerprint);
        }
        expect(baselines.toSet(), hasLength(1), reason: reason);
        expect(
          baselines.toSet().single,
          inInclusiveRange(238, 240),
          reason: reason,
        );
        expect(frameFingerprints, hasLength(contract.frames), reason: reason);
        image.dispose();
        codec.dispose();
      }
    }
  });

  test('Art v3 combat strips satisfy the Pass 2 timing contract', () async {
    const directory = 'assets/images/sprites/art_v3/hero';
    final manifest =
        jsonDecode(File('$directory/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final combat = manifest['combat'] as Map<String, dynamic>;
    const expectedStates = <String>{
      'attack1',
      'attack2',
      'attack3',
      'attack4',
      'attack5',
      'attack6',
      'parry',
      'perfectParry',
      'counter',
      'abilityTransition',
    };

    expect(manifest['version'], 3);
    expect(combat.keys.toSet(), <String>{'sword', 'gauntlet', 'gun'});
    for (final weaponEntry in combat.entries) {
      final states = weaponEntry.value as Map<String, dynamic>;
      expect(states.keys.toSet(), expectedStates, reason: weaponEntry.key);
      for (final stateEntry in states.entries) {
        final sequence = stateEntry.value as Map<String, dynamic>;
        final reason = '${weaponEntry.key}.${stateEntry.key}';
        expect(sequence['state'], stateEntry.key, reason: reason);
        expect(sequence['frames'], 4, reason: reason);
        expect(sequence['fps'], greaterThan(0), reason: reason);
        expect(sequence['loop'], isFalse, reason: reason);
        expect(sequence['pivot'], <num>[0.5, 0.5], reason: reason);
        expect(sequence['eventFrame'], 0, reason: reason);
        final activeFrame = sequence['activeFrame'] as List<dynamic>;
        expect(activeFrame.first, 0, reason: reason);
        expect(activeFrame.last, inInclusiveRange(0, 3), reason: reason);
        expect(
          sequence['promptVersion'],
          'art-v3-pass2-2026-08-11',
          reason: reason,
        );

        final bytes = File('$directory/${sequence['asset']}').readAsBytesSync();
        final codec = await instantiateImageCodec(bytes);
        final decoded = await codec.getNextFrame();
        final image = decoded.image;
        expect(image.width, 1024, reason: reason);
        expect(image.height, 256, reason: reason);
        final data = await image.toByteData(format: ImageByteFormat.rawRgba);
        expect(data, isNotNull, reason: reason);
        final rgba = data!.buffer.asUint8List();
        final fingerprints = <int>{};
        for (var frame = 0; frame < 4; frame += 1) {
          var visible = 0;
          var fingerprint = 17;
          for (var y = 0; y < 256; y += 1) {
            for (var x = 0; x < 256; x += 1) {
              final pixel = (y * image.width + frame * 256 + x) * 4;
              if (rgba[pixel + 3] > 16) visible += 1;
              fingerprint =
                  0x1fffffff &
                  (fingerprint * 31 + rgba[pixel] + rgba[pixel + 3]);
            }
          }
          expect(
            visible / (256 * 256),
            inInclusiveRange(0.025, 0.40),
            reason: reason,
          );
          expect(rgba[(frame * 256) * 4 + 3], 0, reason: reason);
          expect(
            rgba[((255 * image.width) + frame * 256 + 255) * 4 + 3],
            0,
            reason: reason,
          );
          fingerprints.add(fingerprint);
        }
        expect(fingerprints, hasLength(4), reason: reason);
        image.dispose();
        codec.dispose();
      }
    }
  });
}

Set<int> _sampleSilhouette({
  required Uint8List rgba,
  required int stripWidth,
  required int frame,
  required int sourceSize,
  required int displaySize,
}) {
  final silhouette = <int>{};
  for (var y = 0; y < displaySize; y += 1) {
    final sourceY = y * sourceSize ~/ displaySize;
    for (var x = 0; x < displaySize; x += 1) {
      final sourceX = x * sourceSize ~/ displaySize;
      final pixel = (sourceY * stripWidth + frame * sourceSize + sourceX) * 4;
      if (rgba[pixel + 3] > 16) {
        silhouette.add(y * displaySize + x);
      }
    }
  }
  return silhouette;
}

double _jaccardDistance(Set<int> first, Set<int> second) {
  final intersection = first.intersection(second).length;
  final union = first.union(second).length;
  return 1 - intersection / union;
}
