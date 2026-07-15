import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/local_json_store.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final AppLocaleController instance = AppLocaleController._();

  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  Future<void> load() async {
    try {
      final raw = await readLocalJson('app_locale.json');
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final code = decoded['languageCode'] as String?;
      if (!_supportedLanguageCodes.contains(code)) return;
      _locale = Locale(code!);
    } catch (_) {
      _locale = const Locale('fr');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!_supportedLanguageCodes.contains(locale.languageCode)) return;
    if (_locale.languageCode == locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    await writeLocalJson(
      'app_locale.json',
      jsonEncode({'languageCode': _locale.languageCode}),
    );
  }
}

// A previously saved 'en' preference now fails this check and falls back to 'fr'.
const Set<String> _supportedLanguageCodes = {'fr', 'ar'};
