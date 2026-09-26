import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shoe.dart';
import '../models/shoe_filter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../styles/app_styles.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/notification_bell.dart';
import '../widgets/paged_shoe_list.dart';
import '../widgets/shoe_card.dart';
import 'filter_sheet.dart';
import 'orders_screen.dart';
import 'shoe_detail_screen.dart';
import 'shoe_form_screen.dart';

/// Главный экран: каталог с поиском, фильтрами, сортировкой и подгрузкой по 5.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService.instance;
  final _listKey = GlobalKey<PagedShoeListState>();
  TextEditingController? _searchCtrl;
  Timer? _debounce;
  ShoeFilter _filter = const ShoeFilter();
  CatalogMeta? _meta;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int get _userId => context.read<AuthProvider>().user!.id;

  Future<void> _loadMeta() async {
    try {
      final meta = await _api.getMeta();
      if (mounted) setState(() => _meta = meta);
    } on ApiException {
      // Фильтры по брендам/размерам будут недоступны до следующей попытки.
    }
  }

  Future<void> _loadHistory() async {
    final h = await StorageService.getSearchHistory(_userId);
    if (mounted) setState(() => _history = h);
  }

  void _applyFilter(ShoeFilter f) {
    setState(() => _filter = f);
    _listKey.currentState?.reload();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _applyFilter(_filter.copyWith(query: text));
      if (text.trim().length >= 2) {
        StorageService.addSearchQuery(_userId, text).then((_) => _loadHistory());
      }
    });
  }

  void _refreshAll() {
    _listKey.currentState?.reload();
    _loadMeta();
  }

  Future<void> _openFilters() async {
    if (_meta == null) await _loadMeta();
    if (!mounted || _meta == null) return;
    final result = await showModalBottomSheet<ShoeFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => FilterSheet(initial: _filter, meta: _meta!),
    );
    if (result != null) _applyFilter(result);
  }

  Future<void> _openDetail(Shoe shoe, PagedItemControls controls) async {
    final result = await Navigator.push<DetailResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ShoeDetailScreen(shoeId: shoe.id, preview: shoe),
      ),
    );
    if (result == null) return;
    if (result.deleted) {
      controls.remove();
      _loadMeta();
    } else if (result.shoe != null) {
      controls.replace(result.shoe!);
    }
  }

  Future<void> _toggleFavorite(Shoe shoe, PagedItemControls controls) async {
    final value = !shoe.isFavorite;
    controls.replace(shoe.copyWith(isFavorite: value));
    final ok = await runWithErrorHandling(context, () => _api.setFavorite(shoe.id, value));
    if (!ok) {
      controls.replace(shoe);
    } else if (mounted) {
      showMessage(context, value ? 'Добавлено в избранное' : 'Удалено из избранного');
    }
  }

  Future<void> _addShoe() async {
    final created = await Navigator.push<Shoe>(context, MaterialPageRoute(builder: (_) => const ShoeFormScreen()));
    if (created != null && mounted) {
      showMessage(context, 'Модель «${created.fullName}» добавлена');
      _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.directions_run_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: AppStyles.gapM),
            const Flexible(child: Text('Sport Step', overflow: TextOverflow.ellipsis)),
            if (auth.isAdmin) ...[
              const SizedBox(width: AppStyles.gapS),
              const Tag('ADMIN', color: AppColors.secondary),
            ],
          ],
        ),
        actions: [
          NotificationBell(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
          ),
          IconButton(tooltip: 'Обновить', icon: const Icon(Icons.refresh_rounded), onPressed: _refreshAll),
          const SizedBox(width: AppStyles.gapS),
        ],
      ),
      drawer: AppDrawer(onCatalogChanged: _refreshAll),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addShoe,
              icon: const Icon(Icons.add),
              label: const Text('Добавить модель'),
            )
          : null,
      body: ContentWidth(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PagedShoeList(
                key: _listKey,
                loader: (offset, limit) => _api.getShoes(filter: _filter, offset: offset, limit: limit),
                empty: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Ничего не найдено',
                  subtitle: 'Попробуйте изменить запрос или сбросить фильтры',
                  action: OutlinedButton(
                    onPressed: () {
                      _searchCtrl?.clear();
                      _applyFilter(const ShoeFilter());
                    },
                    child: const Text('Сбросить всё'),
                  ),
                ),
                itemBuilder: (context, shoe, controls) => ShoeCard(
                  shoe: shoe,
                  onTap: () => _openDetail(shoe, controls),
                  onFavoriteToggle: auth.isAdmin ? null : () => _toggleFavorite(shoe, controls),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppStyles.gapL, AppStyles.gapL, AppStyles.gapL, AppStyles.gapS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: AppStyles.gapS),
              Badge(
                isLabelVisible: _filter.activeCount > 0,
                label: Text('${_filter.activeCount}'),
                backgroundColor: AppColors.primary,
                child: IconButton.filledTonal(
                  tooltip: 'Фильтры',
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded),
                  style: IconButton.styleFrom(minimumSize: const Size(50, 50)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.gapM),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _categoryChip(null, 'Все', Icons.apps_rounded),
                for (final e in ShoeCategories.labels.entries)
                  _categoryChip(e.key, e.value, ShoeCategories.icon(e.key)),
              ],
            ),
          ),
          const SizedBox(height: AppStyles.gapS),
          Row(
            children: [
              const Icon(Icons.sort_rounded, size: 20, color: AppColors.textMuted),
              const SizedBox(width: AppStyles.gapS),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filter.sort,
                  borderRadius: AppStyles.cardRadius,
                  items: [
                    for (final e in ShoeFilter.sortLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => _applyFilter(_filter.copyWith(sort: v)),
                ),
              ),
              const Spacer(),
              if (_filter.activeCount > 0)
                TextButton.icon(
                  onPressed: () => _applyFilter(_filter.cleared()),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Сбросить фильтры'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Autocomplete<String>(
      // Подсказки — история поиска текущего пользователя (SharedPreferences).
      optionsBuilder: (value) =>
          value.text.isEmpty ? _history : _history.where((h) => h.toLowerCase().contains(value.text.toLowerCase())),
      onSelected: _onSearchChanged,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        _searchCtrl = controller;
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: _onSearchChanged,
            decoration: AppStyles.input('Поиск по названию, бренду, цвету', icon: Icons.search_rounded).copyWith(
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        controller.clear();
                        _onSearchChanged('');
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _categoryChip(String? key, String label, IconData icon) {
    final selected = _filter.category == key;
    return Padding(
      padding: const EdgeInsets.only(right: AppStyles.gapS),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18, color: selected ? Colors.white : null),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600),
        onSelected: (_) => _applyFilter(_filter.copyWith(category: () => key)),
      ),
    );
  }
}
