import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../services/api_service.dart';

/// Счётчик непросмотренных уведомлений.
/// Администратор видит новые заявки клиентов, клиент — ответы на свои заявки.
/// Сервер периодически опрашивается, поэтому уведомление появляется
/// без перезагрузки страницы.
class NotificationProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  Timer? _timer;
  int _unread = 0;
  bool _hasFresh = false;

  int get unread => _unread;

  /// true, если с момента последнего просмотра пришло что-то новое
  /// (используется для «мигания» колокольчика).
  bool get hasFresh => _hasFresh;

  void start() {
    stop();
    refresh();
    _timer = Timer.periodic(AppConfig.notificationsPollInterval, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _unread = 0;
    _hasFresh = false;
  }

  Future<void> refresh() async {
    try {
      final count = await _api.getUnreadCount();
      if (count != _unread) {
        _hasFresh = count > _unread || (count > 0 && _hasFresh);
        _unread = count;
        notifyListeners();
      }
    } on ApiException {
      // Ошибки опроса не показываем пользователю — повторим через интервал.
    }
  }

  Future<void> markAllRead() async {
    if (_unread == 0) return;
    try {
      await _api.markNotificationsRead();
      _unread = 0;
      _hasFresh = false;
      notifyListeners();
    } on ApiException {
      // Счётчик обновится при следующем опросе.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
