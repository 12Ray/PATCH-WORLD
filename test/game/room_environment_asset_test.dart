import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('campaign environment images decode', (tester) async {
    await tester.runAsync(() async {
      for (final path in <String>[
        'assets/images/rooms/damage-lab-environment-v3.png',
        'assets/images/rooms/damage-lab-maintenance-v1.png',
        'assets/images/rooms/damage-lab-hazard-v1.png',
        'assets/images/rooms/damage-lab-environment-v2.png',
        'assets/images/rooms/temporal-hall-environment-v2.png',
        'assets/images/rooms/temporal-ascent-v1.png',
        'assets/images/rooms/temporal-fracture-v1.png',
        'assets/images/rooms/temporal-pendulum-v1.png',
        'assets/images/rooms/collision-archive-environment-v2.png',
        'assets/images/rooms/collision-compression-v1.png',
        'assets/images/rooms/collision-fracture-v1.png',
        'assets/images/rooms/collision-merge-v1.png',
        'assets/images/rooms/optimizer-core-environment-v2.png',
      ]) {
        final data = await rootBundle.load(path);
        final codec = await instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        if (path.contains('optimizer-core') ||
            path.contains('damage-lab-environment-v3') ||
            path.contains('damage-lab-maintenance-v1') ||
            path.contains('damage-lab-hazard-v1') ||
            path.contains('temporal-ascent-v1') ||
            path.contains('temporal-fracture-v1') ||
            path.contains('temporal-pendulum-v1') ||
            path.contains('collision-compression-v1') ||
            path.contains('collision-fracture-v1') ||
            path.contains('collision-merge-v1')) {
          expect(frame.image.width, 1672);
          expect(frame.image.height, 941);
        } else {
          expect(frame.image.width, 1440);
          expect(frame.image.height, 540);
        }
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}
