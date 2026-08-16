import 'dart:convert';

import 'package:patch_world/services/game_settings.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/survival/survival_balance_report.dart';
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
    languageSetupComplete:
        await _store.getBool('languageSetupComplete') ?? false,
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
      _store.setBool('languageSetupComplete', settings.languageSetupComplete),
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

  Future<Set<CampaignTraversalAbility>> loadSurvivalAbilityUnlocks() async {
    final names = await _store.getStringList('survivalAbilityUnlocks');
    if (names == null) return <CampaignTraversalAbility>{};
    return names
        .map((name) {
          for (final ability in CampaignTraversalAbility.values) {
            if (ability.name == name) return ability;
          }
          return null;
        })
        .whereType<CampaignTraversalAbility>()
        .toSet();
  }

  Future<void> saveSurvivalAbilityUnlocks(
    Set<CampaignTraversalAbility> abilities,
  ) => _store.setStringList(
    'survivalAbilityUnlocks',
    abilities.map((ability) => ability.name).toList(growable: false)..sort(),
  );

  Future<List<SurvivalPlaytestRecord>> loadSurvivalPlaytestRecords() async {
    final encoded = await _store.getStringList('survivalPlaytestRecords');
    if (encoded == null) return <SurvivalPlaytestRecord>[];
    final records = <SurvivalPlaytestRecord>[];
    for (final value in encoded) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map) continue;
        records.add(
          SurvivalPlaytestRecord.fromJson(Map<String, Object?>.from(decoded)),
        );
      } catch (_) {
        // A single stale or partially written run must not discard valid runs.
      }
    }
    final start = records.length > SurvivalBalanceReport.maximumStoredRuns
        ? records.length - SurvivalBalanceReport.maximumStoredRuns
        : 0;
    return records.sublist(start);
  }

  Future<void> saveSurvivalPlaytestRecords(
    Iterable<SurvivalPlaytestRecord> records,
  ) {
    final allRecords = records.toList(growable: false);
    final start = allRecords.length > SurvivalBalanceReport.maximumStoredRuns
        ? allRecords.length - SurvivalBalanceReport.maximumStoredRuns
        : 0;
    return _store.setStringList(
      'survivalPlaytestRecords',
      allRecords
          .sublist(start)
          .map((record) => jsonEncode(record.toJson()))
          .toList(growable: false),
    );
  }
}
