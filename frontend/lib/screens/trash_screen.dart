import 'package:flutter/material.dart';

import '../models/shoe.dart';
import '../services/api_service.dart';
import '../styles/app_styles.dart';
import '../widgets/common.dart';
import '../widgets/paged_shoe_list.dart';
import '../widgets/shoe_card.dart';

/// Корзина: удалённые модели с возможностью восстановления
/// или окончательного удаления (только для администратора).
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final _api = ApiService.instance;

  Future<void> _restore(Shoe shoe, PagedItemControls controls) async {
    if (await runWithErrorHandling(context, () => _api.restoreShoe(shoe.id)) && mounted) {
      controls.remove();
      showMessage(context, '«${shoe.fullName}» восстановлена в каталоге');
    }
  }

  Future<void> _purge(Shoe shoe, PagedItemControls controls) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить навсегда?',
      message: '«${shoe.fullName}» будет удалена без возможности восстановления вместе с отзывами и заявками.',
      confirmText: 'Удалить',
      destructive: true,
    );
    if (!ok || !mounted) return;
    if (await runWithErrorHandling(context, () => _api.purgeShoe(shoe.id)) && mounted) {
      controls.remove();
      showMessage(context, 'Модель удалена окончательно');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Корзина')),
      body: ContentWidth(
        child: PagedShoeList(
          loader: (offset, limit) => _api.getShoes(deleted: true, offset: offset, limit: limit),
          empty: const EmptyState(
            icon: Icons.delete_outline_rounded,
            title: 'Корзина пуста',
            subtitle: 'Удалённые модели появятся здесь, и их можно будет восстановить',
          ),
          itemBuilder: (context, shoe, controls) => Opacity(
            opacity: 0.95,
            child: ShoeCard(
              shoe: shoe,
              onTap: () => showMessage(
                context,
                'Удалена ${formatDate(shoe.deletedAt ?? '')}. Восстановите модель, чтобы открыть её в каталоге.',
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Восстановить',
                    onPressed: () => _restore(shoe, controls),
                    icon: const Icon(Icons.restore_rounded, color: AppColors.success),
                  ),
                  const SizedBox(height: AppStyles.gapS),
                  IconButton(
                    tooltip: 'Удалить навсегда',
                    onPressed: () => _purge(shoe, controls),
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
