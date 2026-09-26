import 'package:flutter/material.dart';

import '../models/shoe.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import '../widgets/paged_shoe_list.dart';
import '../widgets/shoe_card.dart';
import 'shoe_detail_screen.dart';

/// Избранные модели текущего пользователя (хранятся на сервере,
/// поэтому сохраняются между сеансами и на разных устройствах).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _api = ApiService.instance;
  final _listKey = GlobalKey<PagedShoeListState>();

  Future<void> _remove(Shoe shoe, PagedItemControls controls) async {
    final ok = await runWithErrorHandling(context, () => _api.setFavorite(shoe.id, false));
    if (!ok || !mounted) return;
    controls.remove();
    showMessage(
      context,
      '«${shoe.fullName}» удалена из избранного',
      action: SnackBarAction(
        label: 'Вернуть',
        textColor: Colors.white,
        onPressed: () async {
          await _api.setFavorite(shoe.id, true);
          _listKey.currentState?.reload();
        },
      ),
    );
  }

  Future<void> _open(Shoe shoe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShoeDetailScreen(shoeId: shoe.id, preview: shoe),
      ),
    );
    _listKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Избранное')),
      body: ContentWidth(
        child: PagedShoeList(
          key: _listKey,
          loader: (offset, limit) => _api.getShoes(favorites: true, offset: offset, limit: limit),
          empty: const EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'В избранном пока пусто',
            subtitle: 'Нажмите на сердечко у понравившейся модели, чтобы сохранить её здесь',
          ),
          itemBuilder: (context, shoe, controls) =>
              ShoeCard(shoe: shoe, onTap: () => _open(shoe), onFavoriteToggle: () => _remove(shoe, controls)),
        ),
      ),
    );
  }
}
