import 'package:flutter/material.dart';

import '../config.dart';
import '../styles/app_styles.dart';
import 'loading.dart';

/// Изображение модели с заглушкой при загрузке и при ошибке.
class ShoeImage extends StatelessWidget {
  final String url;
  final String category;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ShoeImage({super.key, required this.url, required this.category, this.fit = BoxFit.cover, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final full = AppConfig.imageUrl(url);
    Widget child = full.isEmpty
        ? _Placeholder(category: category)
        : Image.network(
            full,
            fit: fit,
            // Позволяет показывать картинки со сторонних сайтов без CORS-заголовков.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : Shimmer(child: Container(color: Colors.white)),
            errorBuilder: (_, _, _) => _Placeholder(category: category),
          );
    if (borderRadius != null) child = ClipRRect(borderRadius: borderRadius!, child: child);
    return child;
  }
}

class _Placeholder extends StatelessWidget {
  final String category;
  const _Placeholder({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = ShoeCategories.color(category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(ShoeCategories.icon(category), size: 48, color: Colors.white)),
    );
  }
}
