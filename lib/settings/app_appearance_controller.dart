import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/current_user_session.dart';

class AppAppearanceController extends ChangeNotifier {
  AppAppearanceController._();

  static final AppAppearanceController instance = AppAppearanceController._();

  AppThemePreference _theme = AppThemePreference.system;
  AppTextSizePreference _textSize = AppTextSizePreference.medium;
  bool _autoBrightness = true;
  bool _powerSavingMode = false;
  Map<String, dynamic> _users = {};

  AppThemePreference get theme => _theme;
  AppTextSizePreference get textSize => _textSize;
  bool get autoBrightness => _autoBrightness;
  bool get powerSavingMode => _powerSavingMode;

  ThemeMode get themeMode {
    return switch (_theme) {
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
      AppThemePreference.system => ThemeMode.system,
    };
  }

  double get textScaleFactor {
    return switch (_textSize) {
      AppTextSizePreference.small => 0.9,
      AppTextSizePreference.medium => 1,
      AppTextSizePreference.large => 1.12,
    };
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        _applyToCurrentUser();
        return;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        _applyToCurrentUser();
        return;
      }

      _users = decoded['users'] is Map<String, dynamic>
          ? decoded['users'] as Map<String, dynamic>
          : {};
      _readPreferenceMap(decoded);
      _applyToCurrentUser();
    } catch (_) {
      _theme = AppThemePreference.system;
      _textSize = AppTextSizePreference.medium;
      _autoBrightness = true;
      _powerSavingMode = false;
      _applyToCurrentUser();
    }
  }

  Future<void> applyUser(AuthenticatedUser user) async {
    final savedUser = _users[user.email];
    if (savedUser is Map<String, dynamic>) {
      _readPreferenceMap(savedUser);
    }
    _applyToUser(user);
    notifyListeners();
  }

  Future<void> setTheme(AppThemePreference value) async {
    if (_theme == value) return;
    _theme = value;
    await _persistChange();
  }

  Future<void> setTextSize(AppTextSizePreference value) async {
    if (_textSize == value) return;
    _textSize = value;
    await _persistChange();
  }

  Future<void> setAutoBrightness(bool value) async {
    if (_autoBrightness == value) return;
    _autoBrightness = value;
    await _persistChange();
  }

  Future<void> setPowerSavingMode(bool value) async {
    if (_powerSavingMode == value) return;
    _powerSavingMode = value;
    await _persistChange();
  }

  Future<void> _persistChange() async {
    _applyToCurrentUser();
    notifyListeners();
    await _save();
  }

  void _readPreferenceMap(Map<String, dynamic> data) {
    _theme = _themeFromName(data['theme']) ?? _theme;
    _textSize = _textSizeFromName(data['textSize']) ?? _textSize;
    _autoBrightness = data['autoBrightness'] is bool
        ? data['autoBrightness'] as bool
        : _autoBrightness;
    _powerSavingMode = data['powerSavingMode'] is bool
        ? data['powerSavingMode'] as bool
        : _powerSavingMode;
  }

  void _applyToCurrentUser() {
    final user = CurrentUserSession.currentUser;
    if (user == null) return;
    _applyToUser(user);
    _users[user.email] = _toJson();
  }

  void _applyToUser(AuthenticatedUser user) {
    user.theme = _theme;
    user.textSize = _textSize;
    user.autoBrightness = _autoBrightness;
    user.powerSavingMode = _powerSavingMode;
  }

  Future<void> _save() async {
    final file = await _file();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    await file.writeAsString(jsonEncode({..._toJson(), 'users': _users}));
  }

  Map<String, dynamic> _toJson() {
    return {
      'theme': _theme.name,
      'textSize': _textSize.name,
      'autoBrightness': _autoBrightness,
      'powerSavingMode': _powerSavingMode,
    };
  }

  static AppThemePreference? _themeFromName(Object? value) {
    if (value is! String) return null;
    return AppThemePreference.values
        .where((theme) => theme.name == value)
        .firstOrNull;
  }

  static AppTextSizePreference? _textSizeFromName(Object? value) {
    if (value is! String) return null;
    return AppTextSizePreference.values
        .where((size) => size.name == value)
        .firstOrNull;
  }

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}app_appearance.json',
    );
  }
}
