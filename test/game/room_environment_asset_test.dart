import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('campaign environment images decode', (tester) async {
    await tester.runAsync(() async {
      for (final path in <String>[
        'assets/images/rooms/damage-lab-environment-v2.png',
        'assets/images/rooms/temporal-hall-environment-v2.png',
        'assets/images/rooms/collision-archive-environment-v2.png',
      ]) {
        final data = await rootBundle.load(path);
        final codec = await instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1440);
        expect(frame.image.height, 540);
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}
