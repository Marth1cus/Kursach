import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/api_service.dart';
import '../styles/app_styles.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';
import '../widgets/shoe_image.dart';
import 'shoe_detail_screen.dart';

/// Заявки на бронирование.
/// Клиент видит свои заявки и ответы администратора,
/// администратор — все заявки и может одобрить или отклонить их.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _api = ApiService.instance;
  List<Order>? _orders;
  String? _error;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _orders = null;
      _error = null;
    });
    try {
      final result = await Future.wait([
        _api.getOrders(status: _status == 'all' ? null : _status),
        Future.delayed(const Duration(milliseconds: 400)),
      ]);
      if (!mounted) return;
      setState(() => _orders = result.first as List<Order>);
      // Пользователь увидел список — уведомления считаются прочитанными.
      await context.read<NotificationProvider>().markAllRead();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _decide(Order o, bool approve) async {
    final comment = await showDialog<String>(
      context: context,
      builder: (_) => _DecisionDialog(approve: approve, order: o),
    );
    if (comment == null || !mounted) return;
    if (await runWithErrorHandling(context, () => _api.decideOrder(o.id, approve: approve, comment: comment)) &&
        mounted) {
      showMessage(context, approve ? 'Заявка одобрена' : 'Заявка отклонена');
      _load();
    }
  }

  Future<void> _cancel(Order o) async {
    final ok = await confirmDialog(
      context,
      title: 'Отменить заявку?',
      message: 'Заявка на ${o.shoeBrand} ${o.shoeName} будет удалена.',
      destructive: true,
      confirmText: 'Отменить заявку',
    );
    if (!ok || !mounted) return;
    if (await runWithErrorHandling(context, () => _api.cancelOrder(o.id)) && mounted) {
      showMessage(context, 'Заявка отменена');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Заявки клиентов' : 'Мои заявки'),
        actions: [IconButton(tooltip: 'Обновить', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppStyles.gapL, AppStyles.gapL, AppStyles.gapL, 0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Все')),
                    ButtonSegment(value: 'pending', label: Text('Новые')),
                    ButtonSegment(value: 'approved', label: Text('Одобренные')),
                    ButtonSegment(value: 'rejected', label: Text('Отклонённые')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (v) {
                    _status = v.first;
                    _load();
                  },
                ),
              ),
            ),
            Expanded(child: _body(isAdmin)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool isAdmin) {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_orders == null) return const Center(child: SneakerLoader(text: 'Загружаем заявки...'));
    if (_orders!.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Заявок нет',
        subtitle: isAdmin
            ? 'Когда клиент забронирует модель, заявка появится здесь, а на колокольчике — уведомление'
            : 'Выберите размер на странице модели и нажмите «Забронировать для примерки»',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: AppStyles.screenPadding,
        itemCount: _orders!.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: AppStyles.gapM),
          child: _OrderCard(
            order: _orders![i],
            isAdmin: isAdmin,
            onApprove: () => _decide(_orders![i], true),
            onReject: () => _decide(_orders![i], false),
            onCancel: () => _cancel(_orders![i]),
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ShoeDetailScreen(shoeId: _orders![i].shoeId)),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool isAdmin;
  final VoidCallback onApprove, onReject, onCancel, onOpen;

  const _OrderCard({
    required this.order,
    required this.isAdmin,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: AppStyles.cardRadius,
        boxShadow: AppStyles.cardShadow(context),
        border: Border.all(color: o.isNew ? AppColors.primary : Colors.transparent, width: 1.5),
      ),
      padding: AppStyles.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tag(o.statusLabel, color: o.statusColor, icon: o.statusIcon),
              if (o.isNew) ...[
                const SizedBox(width: AppStyles.gapS),
                const Tag('НОВОЕ', color: AppColors.primary, icon: Icons.fiber_new_rounded),
              ],
              const Spacer(),
              Text(
                '№${o.id} · ${formatDate(o.createdAt)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.gapM),
          InkWell(
            onTap: onOpen,
            borderRadius: AppStyles.cardRadius,
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  height: 66,
                  child: ShoeImage(
                    url: o.shoeImage,
                    category: 'running',
                    borderRadius: BorderRadius.circular(AppStyles.radiusS),
                  ),
                ),
                const SizedBox(width: AppStyles.gapM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.shoeBrand.toUpperCase(), style: AppStyles.brand),
                      Text(o.shoeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Размер ${o.size} · ${formatPrice(o.shoePrice)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: AppStyles.gapXL),
          if (isAdmin) _line(Icons.person_outline, 'Клиент', o.userName),
          _line(Icons.phone_outlined, 'Телефон', o.phone),
          if (o.comment.isNotEmpty) _line(Icons.chat_bubble_outline, 'Комментарий', o.comment),
          if (o.adminComment.isNotEmpty) _line(Icons.support_agent_outlined, 'Ответ магазина', o.adminComment),
          if (o.isPending) ...[
            const SizedBox(height: AppStyles.gapM),
            if (isAdmin)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Отклонить'),
                    ),
                  ),
                  const SizedBox(width: AppStyles.gapM),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(0, 46)),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Одобрить'),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Отменить заявку'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppStyles.gapXS),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppStyles.gapS),
        Text('$label: ', style: const TextStyle(color: AppColors.textMuted)),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

/// Диалог решения по заявке с необязательным комментарием для клиента.
class _DecisionDialog extends StatefulWidget {
  final bool approve;
  final Order order;
  const _DecisionDialog({required this.approve, required this.order});

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  late final _comment = TextEditingController(
    text: widget.approve ? 'Пара отложена, ждём вас в магазине в течение 3 дней.' : '',
  );

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.approve ? 'Одобрить заявку' : 'Отклонить заявку'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _comment,
          maxLines: 3,
          decoration: AppStyles.input(
            'Комментарий для клиента',
            hint: widget.approve ? null : 'Например: размера нет на складе',
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: widget.approve ? AppColors.success : AppColors.danger),
          onPressed: () => Navigator.pop(context, _comment.text.trim()),
          child: Text(widget.approve ? 'Одобрить' : 'Отклонить'),
        ),
      ],
    );
  }
}
