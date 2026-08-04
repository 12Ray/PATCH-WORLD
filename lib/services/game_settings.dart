import 'package:flutter/foundation.dart';

enum ScreenShakeSetting { full, reduced, off }

enum FlashSetting { full, reduced }

@immutable
final class GameSettings {
  const GameSettings({
    this.bgmVolume = 0.55,
    this.sfxVolume = 0.80,
    this.screenShake = ScreenShakeSetting.full,
    this.flash = FlashSetting.full,
    this.textScale = 1,
    this.assistMode = false,
    this.languageCode = 'ko',
  });

  final double bgmVolume;
  final double sfxVolume;
  final ScreenShakeSetting screenShake;
  final FlashSetting flash;
  final double textScale;
  final bool assistMode;
  final String languageCode;

  GameSettings copyWith({
    double? bgmVolume,
    double? sfxVolume,
    ScreenShakeSetting? screenShake,
    FlashSetting? flash,
    double? textScale,
    bool? assistMode,
    String? languageCode,
  }) => GameSettings(
    bgmVolume: bgmVolume ?? this.bgmVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
    screenShake: screenShake ?? this.screenShake,
    flash: flash ?? this.flash,
    textScale: textScale ?? this.textScale,
    assistMode: assistMode ?? this.assistMode,
    languageCode: languageCode ?? this.languageCode,
  );
}
