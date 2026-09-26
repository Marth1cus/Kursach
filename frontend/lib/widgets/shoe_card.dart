import 'package:flutter/material.dart';

import '../models/shoe.dart';
import '../styles/app_styles.dart';
import 'common.dart';
import 'shoe_image.dart';

/// Карточка модели в списке каталога.
class ShoeCard extends StatefulWidget {
  final Shoe shoe;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;

  /// Дополнительные действия (например, «Восстановить» в корзине).
  final Widget? trailing;

  const ShoeCard({super.key, required this.shoe, required this.onTap, this.onFavoriteToggle, this.trailing});

  @override
  State<ShoeCard> createState() => _ShoeCardState();
}

class _ShoeCardState extends State<ShoeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.shoe;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppStyles.fast,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: AppStyles.cardRadius,
          boxShadow: AppStyles.cardShadow(context),
          border: Border.all(color: _hover ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppStyles.cardRadius,
            onTap: widget.onTap,
            child: Padding(
              padding: AppStyles.cardPadding,
              child: Row(
                children: [
                  _image(s),
                  const SizedBox(width: AppStyles.gapL),
                  Expanded(child: _info(context, s)),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(Shoe s) => SizedBox(
    width: 136,
    height: 108,
    child: Stack(
      children: [
        Positioned.fill(
          child: Hero(
            tag: 'shoe-${s.id}',
            child: ShoeImage(url: s.imageUrl, category: s.category, borderRadius: AppStyles.cardRadius),
          ),
        ),
        if (s.onSale)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '−${s.discountPercent}%',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _info(BuildContext context, Shoe s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(s.brand.toUpperCase(), style: AppStyles.brand)),
          if (widget.onFavoriteToggle != null) _FavoriteButton(active: s.isFavorite, onTap: widget.onFavoriteToggle!),
        ],
      ),
      Text(
        s.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: AppStyles.gapXS),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          Tag(
            ShoeCategories.label(s.category),
            color: ShoeCategories.color(s.category),
            icon: ShoeCategories.icon(s.category),
          ),
          Tag(Genders.label(s.gender), color: AppColors.secondary),
          if (!s.inStock) const Tag('Нет в наличии', color: AppColors.textMuted),
        ],
      ),
      const SizedBox(height: AppStyles.gapS),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatPrice(s.price), style: AppStyles.price),
          if (s.onSale) ...[
            const SizedBox(width: AppStyles.gapS),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(formatPrice(s.oldPrice), style: AppStyles.oldPrice),
            ),
          ],
          const Spacer(),
          if (s.reviewsCount > 0) ...[
            const Icon(Icons.star_rounded, color: AppColors.star, size: 18),
            Text(' ${s.rating.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(' (${s.reviewsCount})', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    ],
  );
}

/// Кнопка «сердечко» с анимацией нажатия.
class _FavoriteButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FavoriteButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 20,
    child: AnimatedSwitcher(
      duration: AppStyles.fast,
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Icon(
        active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        key: ValueKey(active),
        color: active ? AppColors.favorite : AppColors.textMuted,
      ),
    ),
  );
}
