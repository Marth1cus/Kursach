/// Пользователь приложения. Роль определяется сервером при входе.
class User {
  final int id;
  final String login;
  final String name;
  final String role;
  final bool blocked;
  final String createdAt;

  const User({
    required this.id,
    required this.login,
    required this.name,
    required this.role,
    this.blocked = false,
    this.createdAt = '',
  });

  bool get isAdmin => role == 'admin';
  String get roleLabel => isAdmin ? 'Администратор' : 'Клиент';
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as int,
    login: j['login'] as String,
    name: j['name'] as String,
    role: j['role'] as String,
    blocked: (j['blocked'] ?? false) as bool,
    createdAt: (j['created_at'] ?? '') as String,
  );
}
