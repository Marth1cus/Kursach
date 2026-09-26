import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/favorites_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/users_screen.dart';
import '../styles/app_styles.dart';
import 'common.dart';

/// Боковое меню. Набор пунктов зависит от роли пользователя.
class AppDrawer extends StatelessWidget {
  /// Вызывается после возврата с экрана, который мог изменить каталог.
  final VoidCallback? onCatalogChanged;
  const AppDrawer({super.key, this.onCatalogChanged});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final unread = context.watch<NotificationProvider>().unread;
    final user = auth.user!;

    Future<void> open(Widget screen, {bool refresh = false}) async {
      Navigator.pop(context);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      if (refresh) onCatalogChanged?.call();
    }

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              AppStyles.gapXL,
              MediaQuery.paddingOf(context).top + AppStyles.gapXL,
              AppStyles.gapXL,
              AppStyles.gapXL,
            ),
            decoration: BoxDecoration(gradient: user.isAdmin ? AppColors.darkGradient : AppColors.brandGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.initials,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppStyles.gapM),
                Text(
                  user.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(user.isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text('${user.roleLabel} · @${user.login}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppStyles.gapS),
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_rounded),
                  title: const Text('Каталог'),
                  selected: true,
                  onTap: () => Navigator.pop(context),
                ),
                if (!user.isAdmin)
                  ListTile(
                    leading: const Icon(Icons.favorite_rounded),
                    title: const Text('Избранное'),
                    onTap: () => open(const FavoritesScreen(), refresh: true),
                  ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: Text(user.isAdmin ? 'Заявки клиентов' : 'Мои заявки'),
                  trailing: unread > 0 ? Badge(label: Text('$unread'), backgroundColor: AppColors.danger) : null,
                  onTap: () => open(const OrdersScreen()),
                ),
                if (user.isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Корзина'),
                    onTap: () => open(const TrashScreen(), refresh: true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.group_rounded),
                    title: const Text('Пользователи'),
                    onTap: () => open(const UsersScreen()),
                  ),
                ],
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Профиль и настройки'),
                  onTap: () => open(const ProfileScreen()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text('Выйти', style: TextStyle(color: AppColors.danger)),
            onTap: () async {
              final ok = await confirmDialog(
                context,
                title: 'Выход',
                message: 'Вы действительно хотите выйти из аккаунта?',
                confirmText: 'Выйти',
              );
              if (ok && context.mounted) {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
              }
            },
          ),
          const SizedBox(height: AppStyles.gapS),
        ],
      ),
    );
  }
}
