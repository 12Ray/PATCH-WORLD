import 'package:flutter/material.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/game_settings.dart';
import 'package:patch_world/services/localization_service.dart';

final class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xE603050A),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ValueListenableBuilder<GameSettings>(
          valueListenable: game.settings,
          builder: (context, settings, child) => Material(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    game.localization.text('ui.settings'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _VolumeRow(
                    label: game.localization.text('settings.bgm'),
                    value: settings.bgmVolume,
                    onChanged: (value) => game.updateSettings(
                      settings.copyWith(bgmVolume: value),
                    ),
                  ),
                  _VolumeRow(
                    label: game.localization.text('settings.sfx'),
                    value: settings.sfxVolume,
                    onChanged: (value) => game.updateSettings(
                      settings.copyWith(sfxVolume: value),
                    ),
                  ),
                  _VolumeRow(
                    label: game.localization.text('settings.text'),
                    value: settings.textScale,
                    min: 1,
                    max: 1.25,
                    onChanged: (value) => game.updateSettings(
                      settings.copyWith(textScale: value),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: settings.languageCode,
                    decoration: InputDecoration(
                      labelText: game.localization.text('settings.language'),
                    ),
                    items: LocalizationService.supportedLanguages
                        .map(
                          (language) => DropdownMenuItem<String>(
                            value: language.code,
                            child: Text(language.nativeName),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        game.updateSettings(
                          settings.copyWith(languageCode: value),
                        );
                      }
                    },
                  ),
                  SwitchListTile(
                    title: Text(game.localization.text('settings.assist')),
                    subtitle: Text(
                      game.localization.text('settings.assistDescription'),
                    ),
                    value: settings.assistMode,
                    onChanged: (value) => game.updateSettings(
                      settings.copyWith(assistMode: value),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      game.localization.text('settings.reducedFlashes'),
                    ),
                    value: settings.flash == FlashSetting.reduced,
                    onChanged: (value) => game.updateSettings(
                      settings.copyWith(
                        flash: value ? FlashSetting.reduced : FlashSetting.full,
                      ),
                    ),
                  ),
                  DropdownButtonFormField<ScreenShakeSetting>(
                    initialValue: settings.screenShake,
                    decoration: InputDecoration(
                      labelText: game.localization.text('settings.screenShake'),
                    ),
                    items: ScreenShakeSetting.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              game.localization.text(
                                'settings.screenShake.${value.name}',
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        game.updateSettings(
                          settings.copyWith(screenShake: value),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: game.closeSettings,
                      child: Text(game.localization.text('ui.back')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(width: 52, child: Text(label)),
      Expanded(
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
      SizedBox(width: 42, child: Text('${(value * 100).round()}%')),
    ],
  );
}
