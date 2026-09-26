import 'package:flutter/foundation.dart';

/// Настройки подключения к серверу.
class AppConfig {
  AppConfig._();

  /// Адрес API можно переопределить при запуске:
  /// flutter run -d chrome --dart-define=API_URL=http://192.168.1.10:8080
  static const String _apiOverride = String.fromEnvironment('API_URL');

  /// Базовый адрес сервера (без /api).
  static String get serverUrl {
    if (_apiOverride.isNotEmpty) return _apiOverride;
    // Если веб-сборка раздаётся самим Go-сервером — обращаемся к тому же адресу.
    if (kIsWeb && Uri.base.port == 8080) return Uri.base.origin;
    return 'http://localhost:8080';
  }

  static String get apiUrl => '$serverUrl/api';

  /// Количество элементов, подгружаемых за один раз (по ТЗ — 5).
  static const int pageSize = 5;

  /// Период опроса сервера на наличие новых уведомлений.
  static const Duration notificationsPollInterval = Duration(seconds: 8);

  static const Duration requestTimeout = Duration(seconds: 10);

  /// Преобразует относительный путь изображения в полный URL.
  static String imageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('/')) return '$serverUrl$url';
    return url;
  }
}
