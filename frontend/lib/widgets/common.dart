import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../styles/app_styles.dart';

/// Ограничивает ширину контента на широких экранах и центрирует его.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentWidth({super.key, required this.child, this.maxWidth = AppStyles.maxContentWidth});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Заглушка для пустого списка.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.gapXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppStyles.gapXL),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: AppStyles.gapL),
            Text(title, textAlign: TextAlign.center, style: AppStyles.sectionTitle),
            if (subtitle != null) ...[
              const SizedBox(height: AppStyles.gapS),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppStyles.gapL), action!],
          ],
        ),
      ),
    );
  }
}

/// Сообщение об ошибке с кнопкой повтора.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.wifi_off_rounded,
    title: 'Не удалось загрузить данные',
    subtitle: message,
    action: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Повторить')),
  );
}

/// Звёзды рейтинга.
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  const RatingStars({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      final icon = rating >= i + 1
          ? Icons.star_rounded
          : rating > i
          ? Icons.star_half_rounded
          : Icons.star_outline_rounded;
      return Icon(icon, size: size, color: AppColors.star);
    }),
  );
}

/// Небольшой цветной бейдж.
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Tag(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    // В тёмной теме осветляем цвет, чтобы тёмные оттенки оставались читаемыми.
    final color = AppStyles.isDark(context) ? Color.lerp(this.color, Colors.white, 0.45)! : this.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppStyles.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(
            text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Форматирование цены: 13990 → «13 990 ₽».
String formatPrice(int price) {
  final s = price.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '$buf ₽';
}

/// Форматирование даты из формата сервера «2026-09-26 20:50:13».
String formatDate(String raw, {bool withTime = true}) {
  final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (d == null) return raw;
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${two(d.day)}.${two(d.month)}.${d.year}';
  return withTime ? '$date ${two(d.hour)}:${two(d.minute)}' : date;
}

/// Показ сообщений пользователю.
void showMessage(BuildContext context, String text, {bool error = false, SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: AppStyles.gapM),
            Expanded(child: Text(text)),
          ],
        ),
        backgroundColor: error ? AppColors.danger : AppColors.navy,
        action: action,
      ),
    );
}

/// Выполняет действие и показывает ошибку, если она возникла.
Future<bool> runWithErrorHandling(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showMessage(context, e.message, error: true);
    return false;
  }
}

/// Диалог подтверждения.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Подтвердить',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}
