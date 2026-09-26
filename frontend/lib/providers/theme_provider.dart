import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Выбор светлой/тёмной темы с сохранением в SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final saved = await StorageService.getTheme();
    _mode = switch (saved) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await StorageService.saveTheme(mode.name);
  }
}
