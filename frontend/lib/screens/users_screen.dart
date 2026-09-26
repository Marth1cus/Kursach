import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../styles/app_styles.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';

/// Управление пользователями: блокировка и разблокировка клиентов.
/// Список заблокированных хранится в БД и сохраняется между сеансами.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _api = ApiService.instance;
  List<User>? _users;
  String? _error;
  bool _onlyBlocked = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final users = await _api.getUsers();
      if (mounted) setState(() => _users = users);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggle(User u, bool block) async {
    if (block) {
      final ok = await confirmDialog(
        context,
        title: 'Заблокировать пользователя?',
        message: '${u.name} (@${u.login}) не сможет войти в приложение, а текущие сеансы будут завершены.',
        confirmText: 'Заблокировать',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    if (await runWithErrorHandling(context, () => _api.setUserBlocked(u.id, block)) && mounted) {
      showMessage(context, block ? 'Пользователь заблокирован' : 'Пользователь разблокирован');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = (_users ?? [])
        .where((u) => !_onlyBlocked || u.blocked)
        .where(
          (u) =>
              _query.isEmpty ||
              u.name.toLowerCase().contains(_query.toLowerCase()) ||
              u.login.contains(_query.toLowerCase()),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Пользователи')),
      body: ContentWidth(
        child: _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _users == null
            ? const Center(child: SneakerLoader())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppStyles.gapL, AppStyles.gapL, AppStyles.gapL, 0),
                    child: TextField(
                      decoration: AppStyles.input('Поиск по имени или логину', icon: Icons.search),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppStyles.gapL),
                    title: Text('Только заблокированные (${_users!.where((u) => u.blocked).length})'),
                    value: _onlyBlocked,
                    onChanged: (v) => setState(() => _onlyBlocked = v ?? false),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const EmptyState(icon: Icons.person_search_outlined, title: 'Пользователи не найдены')
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: AppStyles.gapL),
                            itemCount: list.length,
                            itemBuilder: (context, i) => _tile(list[i]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tile(User u) => Card(
    margin: const EdgeInsets.only(bottom: AppStyles.gapS),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor:
            (u.blocked
                    ? AppColors.danger
                    : u.isAdmin
                    ? AppColors.secondary
                    : AppColors.primary)
                .withValues(alpha: 0.15),
        child: Icon(
          u.blocked
              ? Icons.block
              : u.isAdmin
              ? Icons.admin_panel_settings
              : Icons.person,
          color: u.blocked
              ? AppColors.danger
              : u.isAdmin
              ? AppColors.secondary
              : AppColors.primary,
        ),
      ),
      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('@${u.login} · ${u.roleLabel} · с ${formatDate(u.createdAt, withTime: false)}'),
      trailing: u.isAdmin
          ? const Tag('ADMIN', color: AppColors.secondary)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  u.blocked ? 'Заблокирован' : 'Активен',
                  style: TextStyle(
                    color: u.blocked ? AppColors.danger : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppStyles.gapS),
                Switch(
                  value: !u.blocked,
                  activeTrackColor: AppColors.success,
                  onChanged: (active) => _toggle(u, !active),
                ),
              ],
            ),
    ),
  );
}
