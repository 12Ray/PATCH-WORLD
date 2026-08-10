import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/language_selection_view.dart';

void main() {
  testWidgets('first-run selector exposes all supported languages', (
    tester,
  ) async {
    String? selectedCode;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LanguageSelectionView(
          onSelected: (code) async => selectedCode = code,
        ),
      ),
    );

    expect(find.text('한국어'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);

    await tester.tap(find.text('日本語'));
    await tester.pump();
    expect(selectedCode, 'ja');
  });
}
