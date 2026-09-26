import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/review.dart';
import '../models/shoe.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../styles/app_styles.dart';
import '../widgets/common.dart';
import '../widgets/loading.dart';
import '../widgets/shoe_image.dart';
import 'shoe_form_screen.dart';

/// Результат работы экрана деталей для обновления списка.
class DetailResult {
  final Shoe? shoe;
  final bool deleted;
  const DetailResult({this.shoe, this.deleted = false});
}

/// Подробная информация о модели.
class ShoeDetailScreen extends StatefulWidget {
  final int shoeId;

  /// Данные из списка — показываются сразу, пока грузится полная версия.
  final Shoe? preview;

  const ShoeDetailScreen({super.key, required this.shoeId, this.preview});

  @override
  State<ShoeDetailScreen> createState() => _ShoeDetailScreenState();
}

class _ShoeDetailScreenState extends State<ShoeDetailScreen> {
  final ApiService _api = ApiService.instance;
  Shoe? _shoe;
  List<Review>? _reviews;
  String? _error;
  String? _selectedSize;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _shoe = widget.preview;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([_api.getShoe(widget.shoeId), _api.getReviews(widget.shoeId)]);
      if (!mounted) return;
      setState(() {
        _shoe = results[0] as Shoe;
        _reviews = results[1] as List<Review>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _close() => Navigator.pop(context, _changed ? DetailResult(shoe: _shoe) : null);

  Future<void> _toggleFavorite() async {
    final s = _shoe!;
    setState(() => _shoe = s.copyWith(isFavorite: !s.isFavorite));
    final ok = await runWithErrorHandling(context, () => _api.setFavorite(s.id, !s.isFavorite));
    if (!ok) {
      setState(() => _shoe = s);
    } else {
      _changed = true;
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<Shoe>(context, MaterialPageRoute(builder: (_) => ShoeFormScreen(shoe: _shoe)));
    if (updated != null && mounted) {
      setState(() => _shoe = updated.copyWith(isFavorite: _shoe!.isFavorite));
      _changed = true;
      showMessage(context, 'Изменения сохранены');
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить модель?',
      message: '«${_shoe!.fullName}» будет перемещена в корзину. Её можно будет восстановить.',
      confirmText: 'В корзину',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await runWithErrorHandling(context, () => _api.deleteShoe(_shoe!.id));
    if (done && mounted) {
      showMessage(context, 'Модель перемещена в корзину');
      Navigator.pop(context, const DetailResult(deleted: true));
    }
  }

  Future<void> _book() async {
    if (_selectedSize == null) {
      showMessage(context, 'Сначала выберите размер', error: true);
      return;
    }
    final booked = await showDialog<bool>(
      context: context,
      builder: (_) => _BookingDialog(shoe: _shoe!, size: _selectedSize!),
    );
    if (booked == true && mounted) {
      showMessage(context, 'Заявка отправлена! Администратор скоро её рассмотрит.');
    }
  }

  Future<void> _addReview() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _ReviewDialog(shoeId: _shoe!.id),
    );
    if (added == true && mounted) {
      _changed = true;
      await _load();
      if (mounted) showMessage(context, 'Спасибо за отзыв!');
    }
  }

  Future<void> _deleteReview(Review r) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить отзыв?',
      message: 'Отзыв пользователя ${r.userName} будет удалён.',
      destructive: true,
      confirmText: 'Удалить',
    );
    if (!ok || !mounted) return;
    if (await runWithErrorHandling(context, () => _api.deleteReview(r.id))) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = _shoe;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: s == null
            ? (_error != null
                  ? SafeArea(
                      child: ErrorState(message: _error!, onRetry: _load),
                    )
                  : const Center(child: SneakerLoader(text: 'Загружаем модель...')))
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 360,
                    leading: BackButton(onPressed: _close),
                    actions: [
                      if (!auth.isAdmin)
                        IconButton(
                          tooltip: s.isFavorite ? 'Убрать из избранного' : 'В избранное',
                          onPressed: _toggleFavorite,
                          icon: Icon(
                            s.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: s.isFavorite ? AppColors.favorite : null,
                          ),
                        ),
                      if (auth.isAdmin) ...[
                        IconButton(tooltip: 'Редактировать', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
                        IconButton(
                          tooltip: 'Удалить в корзину',
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                      const SizedBox(width: AppStyles.gapS),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      // Фото целиком по центру, по краям — его размытая копия.
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                            child: ShoeImage(url: s.imageUrl, category: s.category),
                          ),
                          Center(
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: Hero(
                                tag: 'shoe-${s.id}',
                                child: ShoeImage(url: s.imageUrl, category: s.category),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ContentWidth(
                      child: Padding(padding: AppStyles.screenPadding, child: _details(s, auth)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _details(Shoe s, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.brand.toUpperCase(), style: AppStyles.brand),
        const SizedBox(height: AppStyles.gapXS),
        Text(s.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppStyles.gapS),
        Wrap(
          spacing: AppStyles.gapS,
          runSpacing: AppStyles.gapS,
          children: [
            Tag(
              ShoeCategories.label(s.category),
              color: ShoeCategories.color(s.category),
              icon: ShoeCategories.icon(s.category),
            ),
            Tag(Genders.label(s.gender), color: AppColors.secondary),
            s.inStock
                ? const Tag('В наличии', color: AppColors.success, icon: Icons.check_rounded)
                : const Tag('Нет в наличии', color: AppColors.textMuted, icon: Icons.close_rounded),
            if (s.onSale) Tag('Скидка ${s.discountPercent}%', color: AppColors.danger, icon: Icons.local_offer),
          ],
        ),
        const SizedBox(height: AppStyles.gapL),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatPrice(s.price), style: AppStyles.price.copyWith(fontSize: 30)),
            if (s.onSale) ...[
              const SizedBox(width: AppStyles.gapM),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(formatPrice(s.oldPrice), style: AppStyles.oldPrice.copyWith(fontSize: 17)),
              ),
            ],
            const Spacer(),
            if (s.reviewsCount > 0) ...[
              RatingStars(rating: s.rating, size: 20),
              Text(
                ' ${s.rating.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppStyles.gapXL),

        // Выбор размера (ChoiceChip)
        const Text('Размер (EU)', style: AppStyles.sectionTitle),
        const SizedBox(height: AppStyles.gapS),
        Wrap(
          spacing: AppStyles.gapS,
          runSpacing: AppStyles.gapS,
          children: [
            for (final size in s.sizes)
              ChoiceChip(
                label: Text(size, style: const TextStyle(fontWeight: FontWeight.w700)),
                selected: _selectedSize == size,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _selectedSize == size ? Colors.white : null),
                showCheckmark: false,
                onSelected: (sel) => setState(() => _selectedSize = sel ? size : null),
              ),
          ],
        ),
        if (!auth.isAdmin) ...[
          const SizedBox(height: AppStyles.gapL),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: s.inStock ? _book : null,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(s.inStock ? 'Забронировать для примерки' : 'Нет в наличии'),
            ),
          ),
        ],
        const SizedBox(height: AppStyles.gapXL),

        const Text('Описание', style: AppStyles.sectionTitle),
        const SizedBox(height: AppStyles.gapS),
        Text(
          s.description.isEmpty ? 'Описание отсутствует.' : s.description,
          style: const TextStyle(height: 1.5, fontSize: 15),
        ),
        const SizedBox(height: AppStyles.gapXL),

        const Text('Характеристики', style: AppStyles.sectionTitle),
        const SizedBox(height: AppStyles.gapS),
        _specs(s),
        const SizedBox(height: AppStyles.gapXL),

        Row(
          children: [
            Text('Отзывы (${_reviews?.length ?? s.reviewsCount})', style: AppStyles.sectionTitle),
            const Spacer(),
            if (!auth.isAdmin)
              TextButton.icon(
                onPressed: _addReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Написать отзыв'),
              ),
          ],
        ),
        const SizedBox(height: AppStyles.gapS),
        _reviewsList(auth),
        const SizedBox(height: AppStyles.gapXXL),
      ],
    );
  }

  Widget _specs(Shoe s) {
    final rows = <(IconData, String, String)>[
      (Icons.palette_outlined, 'Цвет', s.color),
      (Icons.layers_outlined, 'Материал верха', s.material),
      (Icons.landscape_outlined, 'Покрытие', s.surface),
      (Icons.scale_outlined, 'Вес', s.weight > 0 ? '${s.weight} г' : ''),
      (Icons.straighten_outlined, 'Размерный ряд', s.sizes.isEmpty ? '' : '${s.sizes.first}–${s.sizes.last}'),
    ].where((r) => r.$3.isNotEmpty).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: AppStyles.cardRadius,
        boxShadow: AppStyles.cardShadow(context),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(rows[i].$1, color: AppColors.primary),
              title: Text(rows[i].$2, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
              trailing: Text(rows[i].$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewsList(AuthProvider auth) {
    if (_reviews == null) {
      return const Padding(
        padding: EdgeInsets.all(AppStyles.gapL),
        child: Center(child: SneakerLoader(size: 32)),
      );
    }
    if (_reviews!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppStyles.gapL),
        child: Text('Отзывов пока нет — будьте первым!', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return Column(
      children: [
        for (final r in _reviews!)
          Padding(
            padding: const EdgeInsets.only(bottom: AppStyles.gapS),
            child: Card(
              child: Padding(
                padding: AppStyles.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            r.userName.characters.first,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: AppStyles.gapS),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                formatDate(r.createdAt, withTime: false),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        RatingStars(rating: r.rating.toDouble()),
                        if (auth.isAdmin || auth.user!.id == r.userId)
                          IconButton(
                            tooltip: 'Удалить отзыв',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _deleteReview(r),
                          ),
                      ],
                    ),
                    if (r.text.isNotEmpty) ...[
                      const SizedBox(height: AppStyles.gapS),
                      Text(r.text, style: const TextStyle(height: 1.4)),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Диалог бронирования пары выбранного размера.
class _BookingDialog extends StatefulWidget {
  final Shoe shoe;
  final String size;
  const _BookingDialog({required this.shoe, required this.size});

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController.fromValue(
    const TextEditingValue(text: '+7 ', selection: TextSelection.collapsed(offset: 3)),
  );
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ApiService.instance.createOrder(
        shoeId: widget.shoe.id,
        size: widget.size,
        phone: _phone.text.trim(),
        comment: _comment.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showMessage(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Бронирование'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.shoe.fullName}, размер ${widget.size}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(formatPrice(widget.shoe.price), style: AppStyles.price),
              const SizedBox(height: AppStyles.gapL),
              TextFormField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]'))],
                decoration: AppStyles.input('Телефон для связи', icon: Icons.phone_outlined),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  return digits.length < 10 || digits.length > 15 ? 'Введите корректный номер телефона' : null;
                },
              ),
              const SizedBox(height: AppStyles.gapM),
              TextFormField(
                controller: _comment,
                maxLines: 3,
                maxLength: 500,
                decoration: AppStyles.input('Комментарий (необязательно)', icon: Icons.chat_bubble_outline),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Отправить заявку'),
        ),
      ],
    );
  }
}

/// Диалог добавления отзыва с выбором оценки звёздами.
class _ReviewDialog extends StatefulWidget {
  final int shoeId;
  const _ReviewDialog({required this.shoeId});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ApiService.instance.addReview(widget.shoeId, _rating, _text.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showMessage(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ваш отзыв'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 36,
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.star),
                  ),
              ],
            ),
            const SizedBox(height: AppStyles.gapS),
            TextField(
              controller: _text,
              maxLines: 4,
              maxLength: 1000,
              decoration: AppStyles.input('Расскажите о впечатлениях'),
            ),
            const Text(
              'Повторный отзыв заменит предыдущий.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _sending ? null : _send, child: const Text('Опубликовать')),
      ],
    );
  }
}
