import 'package:patch_world/services/game_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class SettingsService {
  SettingsService({SharedPreferencesAsync? preferences}) {
    _preferences = preferences;
  }

  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  Future<GameSettings> load() async => GameSettings(
    bgmVolume: await _store.getDouble('bgmVolume') ?? 0.55,
    sfxVolume: await _store.getDouble('sfxVolume') ?? 0.80,
    screenShake: ScreenShakeSetting.values.byName(
      await _store.getString('screenShake') ?? 'full',
    ),
    flash: FlashSetting.values.byName(
      await _store.getString('flash') ?? 'full',
    ),
    textScale: await _store.getDouble('textScale') ?? 1,
    assistMode: await _store.getBool('assistMode') ?? false,
    languageCode: await _store.getString('languageCode') ?? 'ko',
  );

  Future<void> save(GameSettings settings) async {
    await Future.wait(<Future<void>>[
      _store.setDouble('bgmVolume', settings.bgmVolume),
      _store.setDouble('sfxVolume', settings.sfxVolume),
      _store.setString('screenShake', settings.screenShake.name),
      _store.setString('flash', settings.flash.name),
      _store.setDouble('textScale', settings.textScale),
      _store.setBool('assistMode', settings.assistMode),
      _store.setString('languageCode', settings.languageCode),
    ]);
  }

  Future<int> loadBestScore() async => await _store.getInt('bestScore') ?? 0;

  Future<void> saveBestScore(int score) => _store.setInt('bestScore', score);

  Future<int> loadBestSurvivalScore() async =>
      await _store.getInt('bestSurvivalScore') ?? 0;

  Future<double> loadBestSurvivalTime() async =>
      await _store.getDouble('bestSurvivalTime') ?? 0;

  Future<void> saveBestSurvivalScore(int score) =>
      _store.setInt('bestSurvivalScore', score);

  Future<void> saveBestSurvivalTime(double seconds) =>
      _store.setDouble('bestSurvivalTime', seconds);
}
