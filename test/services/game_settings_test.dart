import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/services/game_settings.dart';

void main() {
  test('copyWith preserves accessibility settings independently', () {
    const original = GameSettings();
    final updated = original.copyWith(
      assistMode: true,
      flash: FlashSetting.reduced,
      screenShake: ScreenShakeSetting.off,
      textScale: 1.25,
    );
    expect(updated.assistMode, isTrue);
    expect(updated.flash, FlashSetting.reduced);
    expect(updated.screenShake, ScreenShakeSetting.off);
    expect(updated.textScale, 1.25);
    expect(updated.bgmVolume, original.bgmVolume);
  });
}
