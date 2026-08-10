import 'dart:convert';

import 'package:flutter/services.dart';

final class SupportedLanguage {
  const SupportedLanguage({required this.code, required this.nativeName});

  final String code;
  final String nativeName;
}

final class LocalizationService {
  static const String fallbackLanguageCode = 'en';
  static const List<SupportedLanguage> supportedLanguages = <SupportedLanguage>[
    SupportedLanguage(code: 'ko', nativeName: '한국어'),
    SupportedLanguage(code: 'en', nativeName: 'English'),
    SupportedLanguage(code: 'ja', nativeName: '日本語'),
  ];

  Map<String, String> _strings = const <String, String>{};
  Map<String, String> _fallbackStrings = const <String, String>{};
  String _languageCode = 'ko';

  String get languageCode => _languageCode;
  Set<String> get keys => Set<String>.unmodifiable(_strings.keys);

  static bool supports(String languageCode) =>
      supportedLanguages.any((language) => language.code == languageCode);

  Future<void> load(String languageCode) async {
    final safeCode = supports(languageCode)
        ? languageCode
        : fallbackLanguageCode;
    final raw = await rootBundle.loadString(
      'assets/localization/$safeCode.json',
    );
    final fallbackRaw = safeCode == fallbackLanguageCode
        ? raw
        : await rootBundle.loadString(
            'assets/localization/$fallbackLanguageCode.json',
          );
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Localization root must be a JSON object.');
    }
    _strings = Map<String, String>.unmodifiable(
      decoded.map((key, value) {
        if (value is! String) {
          throw FormatException('Localization value $key must be a String.');
        }
        return MapEntry<String, String>(key, value);
      }),
    );
    final fallbackDecoded = jsonDecode(fallbackRaw) as Map<String, dynamic>;
    _fallbackStrings = Map<String, String>.unmodifiable(
      fallbackDecoded.map(
        (key, value) => MapEntry<String, String>(key, value as String),
      ),
    );
    _languageCode = safeCode;
  }

  String text(
    String key, {
    Map<String, Object> parameters = const <String, Object>{},
  }) {
    var value = _strings[key] ?? _fallbackStrings[key] ?? '[$key]';
    for (final parameter in parameters.entries) {
      value = value.replaceAll('{${parameter.key}}', '${parameter.value}');
    }
    return value;
  }

  String causeText(String causeId) {
    final exactKey = 'cause.$causeId';
    final exact = text(exactKey);
    if (!exact.startsWith('[')) return exact;

    if (causeId.startsWith('enemy.')) {
      final parts = causeId.split('.');
      final archetype = parts.length > 1 ? parts[1] : '';
      final enemyName = text('enemy.$archetype.name');
      return text(
        'cause.enemy.generic',
        parameters: <String, Object>{
          'enemy': enemyName.startsWith('[')
              ? text('cause.enemy.unknown')
              : enemyName,
        },
      );
    }
    if (causeId.startsWith('hazard.')) return text('cause.hazard.generic');
    if (causeId.startsWith('patch.')) return text('cause.patch.generic');
    return text('cause.unknown');
  }
}
