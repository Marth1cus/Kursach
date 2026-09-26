import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/order.dart';
import '../models/review.dart';
import '../models/shoe.dart';
import '../models/shoe_filter.dart';
import '../models/user.dart';
import 'storage_service.dart';

/// Ошибка обращения к серверу с понятным пользователю сообщением.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;
  bool get isBlocked => statusCode == 403 && message.contains('заблокирован');

  @override
  String toString() => message;
}

/// Клиент REST API сервера каталога.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();
  String? _token;

  /// Вызывается, когда сервер сообщает, что сеанс недействителен
  /// или пользователь заблокирован — приложение выполняет выход.
  void Function(ApiException error)? onSessionExpired;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiUrl}$path').replace(queryParameters: query?.isEmpty ?? true ? null : query);

  /// Общий метод выполнения запроса с обработкой сетевых ошибок и кодов ответа.
  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final request = http.Request(method, _uri(path, query))..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('Сервер не отвечает. Проверьте подключение и попробуйте снова.');
    } on http.ClientException {
      throw const ApiException('Нет соединения с сервером. Убедитесь, что сервер запущен.');
    } catch (_) {
      throw const ApiException('Ошибка сети. Попробуйте позже.');
    }

    final text = utf8.decode(response.bodyBytes);
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } on FormatException {
        data = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final message = (data is Map && data['error'] is String)
        ? data['error'] as String
        : 'Ошибка сервера (${response.statusCode})';
    final error = ApiException(message, statusCode: response.statusCode);
    if (_token != null && (error.isUnauthorized || error.isBlocked) && !path.startsWith('/auth/login')) {
      onSessionExpired?.call(error);
    }
    throw error;
  }

  // ───────────────────────── Авторизация ─────────────────────────

  Future<User> login(String login, String password) => _auth('/auth/login', {'login': login, 'password': password});

  Future<User> register(String login, String password, String name) =>
      _auth('/auth/register', {'login': login, 'password': password, 'name': name});

  Future<User> _auth(String path, Map<String, String> body) async {
    final data = await _send('POST', path, body: body) as Map<String, dynamic>;
    final token = data['token'] as String;
    _token = token;
    await StorageService.saveToken(token);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> me() async => User.fromJson(await _send('GET', '/auth/me') as Map<String, dynamic>);

  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout');
    } on ApiException {
      // Выходим локально, даже если сервер недоступен.
    }
    _token = null;
    await StorageService.clearToken();
  }

  // ───────────────────────── Каталог ─────────────────────────

  Future<ShoePage> getShoes({
    ShoeFilter filter = const ShoeFilter(),
    int offset = 0,
    int limit = AppConfig.pageSize,
    bool favorites = false,
    bool deleted = false,
  }) async {
    final query = {
      ...filter.toQuery(),
      'limit': '$limit',
      'offset': '$offset',
      if (favorites) 'favorites': '1',
      if (deleted) 'deleted': '1',
    };
    final data = await _send('GET', '/shoes', query: query) as Map<String, dynamic>;
    final items = (data['items'] as List).map((e) => Shoe.fromJson(e as Map<String, dynamic>)).toList();
    return ShoePage(items, data['total'] as int);
  }

  Future<Shoe> getShoe(int id) async => Shoe.fromJson(await _send('GET', '/shoes/$id') as Map<String, dynamic>);

  Future<CatalogMeta> getMeta() async => CatalogMeta.fromJson(await _send('GET', '/meta') as Map<String, dynamic>);

  Future<Shoe> saveShoe(Shoe shoe) async {
    final data = shoe.isNew
        ? await _send('POST', '/shoes', body: shoe.toJson())
        : await _send('PUT', '/shoes/${shoe.id}', body: shoe.toJson());
    return Shoe.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteShoe(int id) => _send('DELETE', '/shoes/$id');
  Future<void> restoreShoe(int id) => _send('PUT', '/shoes/$id/restore');
  Future<void> purgeShoe(int id) => _send('DELETE', '/shoes/$id/purge');

  // ───────────────────────── Избранное ─────────────────────────

  Future<void> setFavorite(int shoeId, bool value) => _send(value ? 'POST' : 'DELETE', '/favorites/$shoeId');

  // ───────────────────────── Отзывы ─────────────────────────

  Future<List<Review>> getReviews(int shoeId) async {
    final data = await _send('GET', '/shoes/$shoeId/reviews') as List;
    return data.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addReview(int shoeId, int rating, String text) =>
      _send('POST', '/shoes/$shoeId/reviews', body: {'rating': rating, 'text': text});

  Future<void> deleteReview(int id) => _send('DELETE', '/reviews/$id');

  // ───────────────────────── Заявки и уведомления ─────────────────────────

  Future<List<Order>> getOrders({String? status}) async {
    final data = await _send('GET', '/orders', query: {'status': ?status}) as List;
    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> createOrder({
    required int shoeId,
    required String size,
    required String phone,
    String comment = '',
  }) async {
    final data = await _send(
      'POST',
      '/orders',
      body: {'shoe_id': shoeId, 'size': size, 'phone': phone, 'comment': comment},
    );
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<void> cancelOrder(int id) => _send('DELETE', '/orders/$id');

  Future<void> decideOrder(int id, {required bool approve, String comment = ''}) =>
      _send('PUT', '/orders/$id/${approve ? 'approve' : 'reject'}', body: {'comment': comment});

  Future<int> getUnreadCount() async {
    final data = await _send('GET', '/notifications') as Map<String, dynamic>;
    return data['unread'] as int;
  }

  Future<void> markNotificationsRead() => _send('POST', '/notifications/read');

  // ───────────────────────── Администрирование ─────────────────────────

  Future<List<User>> getUsers() async {
    final data = await _send('GET', '/users') as List;
    return data.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setUserBlocked(int id, bool blocked) => _send('PUT', '/users/$id/${blocked ? 'block' : 'unblock'}');

  Future<Map<String, int>> getStats() async {
    final data = await _send('GET', '/stats') as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, v as int));
  }
}
