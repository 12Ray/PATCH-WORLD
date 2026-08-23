import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
      expect(sequence['baseline'], 0.9375, reason: entry.key);
      expect(sequence['displaySize'], <num>[46, 46], reason: entry.key);
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
              '46x46 gameplay display size',
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
        expect(sequence['baseline'], 0.9375, reason: reason);
        expect(sequence['displaySize'], <num>[46, 46], reason: reason);
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
    final idleSequences = manifest['sequences'] as Map<String, dynamic>;
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
      final idleReferencePixels = await _idleBodyPixelReference(
        directory: directory,
        sequence: idleSequences[weaponEntry.key] as Map<String, dynamic>,
      );
      double? registeredRootX;
      double? registeredFootY;
      expect(states.keys.toSet(), expectedStates, reason: weaponEntry.key);
      for (final stateEntry in states.entries) {
        final sequence = stateEntry.value as Map<String, dynamic>;
        final reason = '${weaponEntry.key}.${stateEntry.key}';
        expect(sequence['state'], stateEntry.key, reason: reason);
        expect(sequence['frames'], 4, reason: reason);
        expect(sequence['fps'], greaterThan(0), reason: reason);
        expect(sequence['loop'], isFalse, reason: reason);
        expect(sequence['pivot'], <num>[0.5, 0.5], reason: reason);
        final expectedEventFrame =
            stateEntry.key.startsWith('attack') || stateEntry.key == 'counter'
            ? 1
            : 0;
        expect(sequence['eventFrame'], expectedEventFrame, reason: reason);
        final activeFrame = sequence['activeFrame'] as List<dynamic>;
        expect(activeFrame.first, 0, reason: reason);
        expect(activeFrame.last, inInclusiveRange(0, 3), reason: reason);
        expect(
          expectedEventFrame,
          inInclusiveRange(activeFrame.first as int, activeFrame.last as int),
          reason: '$reason eventFrame must be active',
        );
        expect(
          sequence['promptVersion'],
          'art-v3-pass2-2026-08-11',
          reason: reason,
        );
        expect(sequence['displaySize'], <num>[46, 46], reason: reason);
        expect(sequence['baseline'], 0.9375, reason: reason);
        expect(sequence['scalePolicy'], 'idle-body-area-v1', reason: reason);
        final manifestReferencePixels = sequence['referenceBodyPixels'] as int;
        expect(
          manifestReferencePixels / idleReferencePixels,
          closeTo(1, 0.01),
          reason: reason,
        );
        expect(
          sequence['registrationVersion'],
          'art-v3-body-component-v2-2026-08-23',
          reason: reason,
        );
        final transforms = sequence['frameTransforms'] as List<dynamic>;
        final bodyRoots = sequence['bodyRoots'] as List<dynamic>;
        final bodyBounds = sequence['bodyBounds'] as List<dynamic>;
        final bodyPixelCounts = sequence['bodyPixelCounts'] as List<dynamic>;
        expect(transforms, hasLength(4), reason: reason);
        expect(bodyRoots, hasLength(4), reason: reason);
        expect(bodyBounds, hasLength(4), reason: reason);
        expect(bodyPixelCounts, hasLength(4), reason: reason);
        final frameScales = <double>[];
        for (var frame = 0; frame < 4; frame += 1) {
          final transform = transforms[frame] as Map<String, dynamic>;
          final root = bodyRoots[frame] as Map<String, dynamic>;
          expect((transform['dx'] as num).toDouble().isFinite, isTrue);
          expect((transform['dy'] as num).toDouble().isFinite, isTrue);
          final scale = (transform['scale'] as num).toDouble();
          expect(
            scale,
            inInclusiveRange(1.15, 2.4),
            reason: '$reason frame $frame',
          );
          frameScales.add(scale);
          expect(root['x'], inInclusiveRange(0, 255));
          expect(root['y'], inInclusiveRange(0, 255));
          expect(
            bodyBounds[frame],
            everyElement(inInclusiveRange(0, 256)),
            reason: '$reason frame $frame',
          );
          expect(
            bodyPixelCounts[frame],
            greaterThan(64),
            reason: '$reason frame $frame',
          );
          expect(
            scale,
            closeTo(
              math.sqrt(
                manifestReferencePixels / (bodyPixelCounts[frame] as int),
              ),
              0.0001,
            ),
            reason: '$reason frame $frame idle-area scale',
          );
          final rootX =
              ((root['x'] as num).toDouble() - 128) * 46 / 256 * scale +
              (transform['dx'] as num).toDouble();
          final footY =
              ((root['y'] as num).toDouble() - 128) * 46 / 256 * scale +
              (transform['dy'] as num).toDouble();
          registeredRootX ??= rootX;
          expect(rootX, closeTo(registeredRootX, .004), reason: reason);
          final airborneSwordFinisher =
              weaponEntry.key == 'sword' &&
              stateEntry.key == 'attack6' &&
              frame < 3;
          if (!airborneSwordFinisher) {
            registeredFootY ??= footY;
            expect(footY, closeTo(registeredFootY, .004), reason: reason);
          } else {
            final authoredOffset = const <double>[-6, -11, -6][frame];
            expect(
              footY,
              closeTo(registeredFootY! + authoredOffset, .004),
              reason: reason,
            );
          }
        }
        expect(
          frameScales.toSet(),
          hasLength(greaterThan(1)),
          reason: '$reason must use measured per-frame body scale',
        );
        expect(
          sequence['presentationScale'],
          closeTo(
            frameScales.reduce((first, second) => first + second) /
                frameScales.length,
            0.0001,
          ),
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
          var deepestVisible = -1;
          var fingerprint = 17;
          for (var y = 0; y < 256; y += 1) {
            for (var x = 0; x < 256; x += 1) {
              final pixel = (y * image.width + frame * 256 + x) * 4;
              if (rgba[pixel + 3] > 16) {
                visible += 1;
                deepestVisible = y;
              }
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
          final detected = _detectBodyLandmark(
            rgba: rgba,
            stripWidth: image.width,
            frame: frame,
            sourceSize: 256,
          );
          final root = bodyRoots[frame] as Map<String, dynamic>;
          expect(
            detected.rootX,
            closeTo(root['x'] as int, 1),
            reason: '$reason frame $frame',
          );
          expect(
            detected.footY,
            closeTo(root['y'] as int, 1),
            reason: '$reason frame $frame',
          );
          final manifestBounds = bodyBounds[frame] as List<dynamic>;
          for (var coordinate = 0; coordinate < 4; coordinate += 1) {
            expect(
              detected.bounds[coordinate],
              closeTo(manifestBounds[coordinate] as int, 2),
              reason: '$reason frame $frame bound $coordinate',
            );
          }
          expect(
            detected.pixelCount / (bodyPixelCounts[frame] as int),
            closeTo(1, 0.015),
            reason: '$reason frame $frame',
          );
          final normalizedBodySize =
              math.sqrt(detected.pixelCount) * frameScales[frame];
          expect(
            normalizedBodySize / math.sqrt(idleReferencePixels),
            closeTo(1, 0.015),
            reason: '$reason frame $frame idle-relative body size',
          );
          if (weaponEntry.key == 'gauntlet' &&
              stateEntry.key == 'counter' &&
              (frame == 0 || frame == 3)) {
            expect(deepestVisible, greaterThanOrEqualTo(250));
            expect(
              detected.footY,
              lessThan(190),
              reason: 'detached bottom VFX must not become the body foot',
            );
          }
          fingerprints.add(fingerprint);
        }
        expect(fingerprints, hasLength(4), reason: reason);
        image.dispose();
        codec.dispose();
      }
    }
  });
}

final class _DetectedBodyLandmark {
  const _DetectedBodyLandmark({
    required this.rootX,
    required this.footY,
    required this.bounds,
    required this.pixelCount,
  });

  final int rootX;
  final int footY;
  final List<int> bounds;
  final int pixelCount;
}

Future<int> _idleBodyPixelReference({
  required String directory,
  required Map<String, dynamic> sequence,
}) async {
  final bytes = File('$directory/${sequence['asset']}').readAsBytesSync();
  final codec = await instantiateImageCodec(bytes);
  final decoded = await codec.getNextFrame();
  final image = decoded.image;
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  expect(data, isNotNull);
  final rgba = data!.buffer.asUint8List();
  final counts = <int>[];
  for (var frame = 0; frame < (sequence['frames'] as int); frame += 1) {
    counts.add(
      _detectBodyLandmark(
        rgba: rgba,
        stripWidth: image.width,
        frame: frame,
        sourceSize: 256,
      ).pixelCount,
    );
  }
  image.dispose();
  codec.dispose();
  return _quantileInt(counts, 0.5);
}

_DetectedBodyLandmark _detectBodyLandmark({
  required Uint8List rgba,
  required int stripWidth,
  required int frame,
  required int sourceSize,
}) {
  final pixelCount = sourceSize * sourceSize;
  final raw = Uint8List(pixelCount);
  for (var y = 0; y < sourceSize; y += 1) {
    for (var x = 0; x < sourceSize; x += 1) {
      final local = y * sourceSize + x;
      final pixel = (y * stripWidth + frame * sourceSize + x) * 4;
      final red = rgba[pixel];
      final green = rgba[pixel + 1];
      final blue = rgba[pixel + 2];
      final alpha = rgba[pixel + 3];
      if (alpha > 64 && red + green + blue < 405 && green <= red + 18) {
        raw[local] = 1;
      }
    }
  }

  final dense = Uint8List(pixelCount);
  for (var y = 0; y < sourceSize; y += 1) {
    for (var x = 0; x < sourceSize; x += 1) {
      final local = y * sourceSize + x;
      if (raw[local] == 0) continue;
      var neighbors = 0;
      for (
        var neighborY = math.max(0, y - 1);
        neighborY <= math.min(sourceSize - 1, y + 1);
        neighborY += 1
      ) {
        for (
          var neighborX = math.max(0, x - 1);
          neighborX <= math.min(sourceSize - 1, x + 1);
          neighborX += 1
        ) {
          if (raw[neighborY * sourceSize + neighborX] != 0) {
            neighbors += 1;
          }
        }
      }
      if (neighbors >= 6) dense[local] = 1;
    }
  }

  final visited = Uint8List(pixelCount);
  List<int>? bestComponent;
  var bestScore = -1.0;
  for (var start = 0; start < pixelCount; start += 1) {
    if (dense[start] == 0 || visited[start] != 0) continue;
    final pending = <int>[start];
    final component = <int>[];
    visited[start] = 1;
    var pendingIndex = 0;
    var sumX = 0;
    var sumY = 0;
    while (pendingIndex < pending.length) {
      final local = pending[pendingIndex++];
      component.add(local);
      final x = local % sourceSize;
      final y = local ~/ sourceSize;
      sumX += x;
      sumY += y;
      for (
        var neighborY = math.max(0, y - 1);
        neighborY <= math.min(sourceSize - 1, y + 1);
        neighborY += 1
      ) {
        for (
          var neighborX = math.max(0, x - 1);
          neighborX <= math.min(sourceSize - 1, x + 1);
          neighborX += 1
        ) {
          final neighbor = neighborY * sourceSize + neighborX;
          if (dense[neighbor] != 0 && visited[neighbor] == 0) {
            visited[neighbor] = 1;
            pending.add(neighbor);
          }
        }
      }
    }
    if (component.length < 64) continue;
    final centerX = sumX / component.length;
    final centerY = sumY / component.length;
    final distance =
        math.pow((centerX - sourceSize / 2) / sourceSize, 2) +
        math.pow((centerY - sourceSize * 0.515) / sourceSize, 2);
    final score = component.length / (1 + 0.35 * distance);
    if (score > bestScore) {
      bestScore = score;
      bestComponent = component;
    }
  }
  if (bestComponent == null) {
    throw StateError('Sprite frame does not contain a body component');
  }

  final xs = <int>[];
  final ys = <int>[];
  for (final local in bestComponent) {
    xs.add(local % sourceSize);
    ys.add(local ~/ sourceSize);
  }
  final lowerCut = _quantileInt(ys, 0.82);
  final lowerXs = <int>[];
  for (var index = 0; index < bestComponent.length; index += 1) {
    if (ys[index] >= lowerCut) lowerXs.add(xs[index]);
  }
  return _DetectedBodyLandmark(
    rootX: _quantileInt(lowerXs, 0.5),
    footY: _quantileInt(ys, 0.99),
    bounds: <int>[
      _quantileInt(xs, 0.01),
      _quantileInt(ys, 0.01),
      _quantileInt(xs, 0.99) + 1,
      _quantileInt(ys, 0.99) + 1,
    ],
    pixelCount: bestComponent.length,
  );
}

int _quantileInt(List<int> values, double fraction) {
  final ordered = values.toList()..sort();
  final position = (ordered.length - 1) * fraction;
  final floor = position.floor();
  final remainder = position - floor;
  final index = (remainder - 0.5).abs() < 1e-12
      ? (floor.isEven ? floor : floor + 1)
      : position.round();
  return ordered[index];
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
