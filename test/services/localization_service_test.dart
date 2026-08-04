import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/services/localization_service.dart';

void main() {
  testWidgets('Korean and English locale assets expose identical keys', (
    tester,
  ) async {
    final korean = LocalizationService();
    final english = LocalizationService();
    await korean.load('ko');
    await english.load('en');

    expect(korean.keys, english.keys);
    expect(korean.text('ui.start'), isNot(startsWith('[')));
    expect(english.text('patch.duplicate_fault.sideEffect'), isNotEmpty);
  });
}
