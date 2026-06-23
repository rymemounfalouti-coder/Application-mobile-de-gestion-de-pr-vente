import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final AppLocaleController instance = AppLocaleController._();

  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
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
    final file = await _file();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      jsonEncode({'languageCode': _locale.languageCode}),
    );
  }

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}app_locale.json');
  }
}

const Set<String> _supportedLanguageCodes = {'fr', 'en', 'ar'};
