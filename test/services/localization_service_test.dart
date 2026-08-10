import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/services/localization_service.dart';

void main() {
  testWidgets('Korean, English, and Japanese assets expose identical keys', (
    tester,
  ) async {
    final korean = LocalizationService();
    final english = LocalizationService();
    final japanese = LocalizationService();
    final fallback = LocalizationService();
    await korean.load('ko');
    await english.load('en');
    await japanese.load('ja');
    await fallback.load('fr');

    expect(korean.keys, english.keys);
    expect(japanese.keys, english.keys);
    expect(korean.text('ui.start'), isNot(startsWith('[')));
    expect(japanese.text('ui.start'), 'パッチ開始');
    expect(english.text('patch.duplicate_fault.sideEffect'), isNotEmpty);
    expect(fallback.languageCode, 'en');
    expect(fallback.text('ui.start'), 'START PATCHING');
  });
}
