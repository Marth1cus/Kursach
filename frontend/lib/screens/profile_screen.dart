import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../styles/app_styles.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';

/// Профиль пользователя и настройки приложения.
/// Для администратора дополнительно выводится статистика каталога.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, int>? _stats;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthProvider>().isAdmin) _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final s = await ApiService.instance.getStats();
      if (mounted) setState(() => _stats = s);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user!;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: AppStyles.screenPadding,
        children: [
          ContentWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppStyles.gapXL),
                  decoration: BoxDecoration(
                    gradient: user.isAdmin ? AppColors.darkGradient : AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(AppStyles.radiusL),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white,
                        child: Text(
                          user.initials,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: AppStyles.gapL),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            Text('@${user.login}', style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: AppStyles.gapS),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                user.roleLabel,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (user.isAdmin) ...[
                  const SizedBox(height: AppStyles.gapXL),
                  const Text('Статистика', style: AppStyles.sectionTitle),
                  const SizedBox(height: AppStyles.gapM),
                  _stats == null ? const Center(child: SneakerLoader(size: 36)) : _statsGrid(_stats!),
                ],
                const SizedBox(height: AppStyles.gapXL),
                const Text('Оформление', style: AppStyles.sectionTitle),
                const SizedBox(height: AppStyles.gapM),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Светлая'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная'), icon: Icon(Icons.dark_mode_outlined)),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Системная'),
                      icon: Icon(Icons.settings_suggest_outlined),
                    ),
                  ],
                  selected: {theme.mode},
                  onSelectionChanged: (v) => theme.setMode(v.first),
                ),
                const SizedBox(height: AppStyles.gapM),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.dark_mode_rounded),
                  title: const Text('Тёмная тема'),
                  value: theme.isDark,
                  onChanged: (v) => theme.setMode(v ? ThemeMode.dark : ThemeMode.light),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: const Text('Очистить историю поиска'),
                  onTap: () async {
                    await StorageService.clearSearchHistory(user.id);
                    if (context.mounted) showMessage(context, 'История поиска очищена');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Сервер'),
                  subtitle: Text(AppConfig.serverUrl),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('О приложении'),
                  subtitle: const Text('Sport Step — каталог спортивной обуви. Курсовая работа, Flutter + Go.'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Sport Step',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.directions_run_rounded, color: AppColors.primary, size: 40),
                    children: const [
                      Text(
                        'Веб-приложение «Каталог спортивной обуви».\n'
                        'Клиентская часть — Flutter (Dart), серверная — Go, база данных — SQLite.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppStyles.gapL),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Выход',
                      message: 'Вы действительно хотите выйти?',
                      confirmText: 'Выйти',
                    );
                    if (ok && context.mounted) await context.read<AuthProvider>().logout();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Выйти из аккаунта'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(Map<String, int> s) {
    final items = [
      (Icons.inventory_2_outlined, 'Моделей в каталоге', s['shoes'], AppColors.primary),
      (Icons.delete_outline, 'В корзине', s['deleted'], AppColors.textMuted),
      (Icons.people_outline, 'Клиентов', s['clients'], AppColors.secondary),
      (Icons.block, 'Заблокировано', s['blocked'], AppColors.danger),
      (Icons.hourglass_top_rounded, 'Новых заявок', s['pending_orders'], AppColors.warning),
      (Icons.receipt_long_outlined, 'Всего заявок', s['orders'], AppColors.success),
      (Icons.rate_review_outlined, 'Отзывов', s['reviews'], AppColors.star),
      (Icons.favorite_border, 'В избранном', s['favorites'], AppColors.favorite),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 600 ? 4 : 2;
        final w = (c.maxWidth - AppStyles.gapM * (cols - 1)) / cols;
        return Wrap(
          spacing: AppStyles.gapM,
          runSpacing: AppStyles.gapM,
          children: [
            for (final it in items)
              Container(
                width: w,
                padding: AppStyles.cardPadding,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: AppStyles.cardRadius,
                  boxShadow: AppStyles.cardShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(it.$1, color: it.$4),
                    const SizedBox(height: AppStyles.gapS),
                    Text('${it.$3 ?? 0}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    Text(it.$2, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
