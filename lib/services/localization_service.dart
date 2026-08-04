import 'dart:convert';

import 'package:flutter/services.dart';

final class LocalizationService {
  Map<String, String> _strings = const <String, String>{};
  String _languageCode = 'ko';

  String get languageCode => _languageCode;

  Future<void> load(String languageCode) async {
    final safeCode = languageCode == 'en' ? 'en' : 'ko';
    final raw = await rootBundle.loadString(
      'assets/localization/$safeCode.json',
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
    _languageCode = safeCode;
  }

  String text(
    String key, {
    Map<String, Object> parameters = const <String, Object>{},
  }) {
    var value = _strings[key] ?? '[$key]';
    for (final parameter in parameters.entries) {
      value = value.replaceAll('{${parameter.key}}', '${parameter.value}');
    }
    return value;
  }
}
