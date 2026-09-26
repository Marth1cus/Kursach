import 'package:shared_preferences/shared_preferences.dart';

/// Локальное хранилище браузера/устройства (SharedPreferences).
/// Хранит токен сеанса, тему оформления, последний логин и историю поиска.
class StorageService {
  StorageService._();

  static const _kToken = 'auth_token';
  static const _kTheme = 'theme_mode';
  static const _kLastLogin = 'last_login';
  static const _kSearchHistory = 'search_history';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<String?> getToken() async => (await _prefs).getString(_kToken);
  static Future<void> saveToken(String token) async => (await _prefs).setString(_kToken, token);
  static Future<void> clearToken() async => (await _prefs).remove(_kToken);

  static Future<String?> getTheme() async => (await _prefs).getString(_kTheme);
  static Future<void> saveTheme(String mode) async => (await _prefs).setString(_kTheme, mode);

  static Future<String?> getLastLogin() async => (await _prefs).getString(_kLastLogin);
  static Future<void> saveLastLogin(String login) async => (await _prefs).setString(_kLastLogin, login);

  /// История поиска хранится отдельно для каждого пользователя.
  static Future<List<String>> getSearchHistory(int userId) async =>
      (await _prefs).getStringList('${_kSearchHistory}_$userId') ?? [];

  static Future<void> addSearchQuery(int userId, String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = await getSearchHistory(userId);
    list
      ..remove(q)
      ..insert(0, q);
    await (await _prefs).setStringList('${_kSearchHistory}_$userId', list.take(6).toList());
  }

  static Future<void> clearSearchHistory(int userId) async => (await _prefs).remove('${_kSearchHistory}_$userId');
}
