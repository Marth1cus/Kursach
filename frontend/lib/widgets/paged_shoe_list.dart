import 'package:flutter/material.dart';

import '../config.dart';
import '../models/shoe.dart';
import '../services/api_service.dart';
import '../styles/app_styles.dart';
import 'common.dart';
import 'loading.dart';

typedef ShoePageLoader = Future<ShoePage> Function(int offset, int limit);

/// Управление элементом списка из карточки: заменить или удалить его.
class PagedItemControls {
  final void Function(Shoe updated) replace;
  final VoidCallback remove;
  const PagedItemControls(this.replace, this.remove);
}

typedef PagedItemBuilder = Widget Function(BuildContext context, Shoe shoe, PagedItemControls controls);

/// Список моделей, построенный через ListView.builder, с постраничной
/// подгрузкой по [AppConfig.pageSize] элементов: следующие элементы
/// подгружаются при прокрутке вниз или по кнопке «Показать ещё».
class PagedShoeList extends StatefulWidget {
  final ShoePageLoader loader;
  final PagedItemBuilder itemBuilder;
  final Widget empty;
  final Widget? header;

  const PagedShoeList({super.key, required this.loader, required this.itemBuilder, required this.empty, this.header});

  @override
  State<PagedShoeList> createState() => PagedShoeListState();
}

class PagedShoeListState extends State<PagedShoeList> {
  final ScrollController _scroll = ScrollController();
  final List<Shoe> _items = [];
  int _total = 0;
  bool _initialLoading = true;
  bool _loadingMore = false;
  String? _error;
  int _generation = 0; // защита от устаревших ответов при быстрой смене фильтров

  bool get _hasMore => _items.length < _total;
  int get total => _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) _loadMore();
  }

  /// Полная перезагрузка списка (после смены фильтров, возврата с другого экрана и т.п.).
  Future<void> reload() async {
    final gen = ++_generation;
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      // Небольшая минимальная задержка, чтобы анимация загрузки не «мелькала».
      final results = await Future.wait([
        widget.loader(0, AppConfig.pageSize),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);
      if (!mounted || gen != _generation) return;
      final page = results.first as ShoePage;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _initialLoading = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } on ApiException catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e.message;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _initialLoading || !_hasMore || _error != null) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final results = await Future.wait([
        widget.loader(_items.length, AppConfig.pageSize),
        Future.delayed(const Duration(milliseconds: 350)),
      ]);
      if (!mounted || gen != _generation) return;
      final page = results.first as ShoePage;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _replace(Shoe updated) {
    final i = _items.indexWhere((s) => s.id == updated.id);
    if (i >= 0) setState(() => _items[i] = updated);
  }

  void _remove(int id) {
    setState(() {
      _items.removeWhere((s) => s.id == id);
      _total = (_total - 1).clamp(0, 1 << 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return Column(
        children: [
          if (widget.header != null) widget.header!,
          const Expanded(child: SkeletonList()),
        ],
      );
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: reload);

    final hasHeader = widget.header != null;
    final itemCount = (hasHeader ? 1 : 0) + (_items.isEmpty ? 1 : _items.length + 1);

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppStyles.gapXXL * 2),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (hasHeader) {
            if (index == 0) return widget.header!;
            index--;
          }
          if (_items.isEmpty) return Padding(padding: const EdgeInsets.only(top: 40), child: widget.empty);
          if (index == _items.length) return _footer();
          final shoe = _items[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppStyles.gapL, AppStyles.gapS, AppStyles.gapL, AppStyles.gapS),
            child: _AppearAnimation(
              key: ValueKey('${shoe.id}-$_generation'),
              delay: Duration(milliseconds: 60 * (index % AppConfig.pageSize)),
              child: widget.itemBuilder(context, shoe, PagedItemControls(_replace, () => _remove(shoe.id))),
            ),
          );
        },
      ),
    );
  }

  Widget _footer() {
    Widget child;
    if (_loadingMore) {
      child = const SneakerLoader(size: 36);
    } else if (_hasMore) {
      child = OutlinedButton.icon(
        onPressed: _loadMore,
        icon: const Icon(Icons.expand_more_rounded),
        label: Text('Показать ещё (осталось ${_total - _items.length})'),
      );
    } else {
      child = Text('Показаны все модели: $_total', style: const TextStyle(color: AppColors.textMuted));
    }
    return Padding(
      padding: const EdgeInsets.all(AppStyles.gapL),
      child: Center(
        child: AnimatedSwitcher(duration: AppStyles.fast, child: child),
      ),
    );
  }
}

/// Плавное появление элемента списка (сдвиг + прозрачность).
class _AppearAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AppearAnimation({super.key, required this.child, required this.delay});

  @override
  State<_AppearAnimation> createState() => _AppearAnimationState();
}

class _AppearAnimationState extends State<_AppearAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppStyles.normal);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(curve),
        child: widget.child,
      ),
    );
  }
}
