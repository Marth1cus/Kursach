import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../styles/app_styles.dart';

/// Кнопка уведомлений в AppBar. При появлении новых событий
/// колокольчик «покачивается» и мигает, а на значке отображается их число.
class NotificationBell extends StatefulWidget {
  final VoidCallback onPressed;
  const NotificationBell({super.key, required this.onPressed});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationProvider>();
    // Запуск/остановка анимации после кадра, чтобы не менять состояние во время build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (n.hasFresh && !_c.isAnimating) {
        _c.repeat();
      } else if (!n.hasFresh && _c.isAnimating) {
        _c
          ..stop()
          ..value = 0;
      }
    });

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Покачивание в первой трети цикла, затем пауза.
        final t = _c.value;
        final swing = t < 0.35 ? math.sin(t / 0.35 * 6 * math.pi) * 0.35 * (1 - t / 0.35) : 0.0;
        final glow = n.hasFresh ? (1 - (t * 2 - 1).abs()) : 0.0;
        return IconButton(
          tooltip: n.unread > 0 ? 'Новых уведомлений: ${n.unread}' : 'Уведомления',
          onPressed: widget.onPressed,
          icon: Badge(
            isLabelVisible: n.unread > 0,
            label: Text('${n.unread}'),
            backgroundColor: AppColors.danger,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  if (glow > 0)
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6 * glow),
                      blurRadius: 14 * glow,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Transform.rotate(
                angle: swing,
                alignment: Alignment.topCenter,
                child: Icon(
                  n.unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  color: n.unread > 0 ? AppColors.primary : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
