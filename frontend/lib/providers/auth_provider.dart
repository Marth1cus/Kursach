import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Состояние авторизации. Роль пользователя приходит с сервера —
/// приложение само определяет, клиент это или администратор.
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;

  User? _user;
  String? _sessionMessage;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// Сообщение о принудительном выходе (например, при блокировке).
  String? takeSessionMessage() {
    final m = _sessionMessage;
    _sessionMessage = null;
    return m;
  }

  AuthProvider() {
    _api.onSessionExpired = (error) {
      if (_user == null) return;
      _sessionMessage = error.message;
      _user = null;
      _api.setToken(null);
      StorageService.clearToken();
      notifyListeners();
    };
  }

  /// Восстановление сеанса по сохранённому токену.
  Future<bool> tryRestoreSession() async {
    final token = await StorageService.getToken();
    if (token == null) return false;
    _api.setToken(token);
    try {
      _user = await _api.me();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.statusCode == 403) {
        await StorageService.clearToken();
        _sessionMessage = e.isBlocked ? e.message : null;
      }
      _api.setToken(null);
      return false;
    }
  }

  Future<void> login(String login, String password) async {
    _user = await _api.login(login.trim(), password);
    await StorageService.saveLastLogin(login.trim());
    notifyListeners();
  }

  Future<void> register(String login, String password, String name) async {
    _user = await _api.register(login.trim(), password, name.trim());
    await StorageService.saveLastLogin(login.trim());
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    notifyListeners();
  }
}
