import 'package:flutter_test/flutter_test.dart';

import '../support/art_v3_runtime_assertion.dart';

void main() {
  testWidgets('Optimizer Core loads all boss and foreground Art v3 visuals', (
    tester,
  ) async {
    await expectOptimizerArtV3Loaded(tester);
  });
}
