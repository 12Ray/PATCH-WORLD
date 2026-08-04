import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/services/settings_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  test('survival best score and time persist independently', () async {
    final service = SettingsService();
    await service.saveBestSurvivalScore(9001);
    await service.saveBestSurvivalTime(183.5);

    expect(await SettingsService().loadBestSurvivalScore(), 9001);
    expect(await SettingsService().loadBestSurvivalTime(), 183.5);
  });
}
