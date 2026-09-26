import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/app_styles.dart';

/// Анимация загрузки: «бегущий» значок, прыгающий над тенью,
/// и три пульсирующие точки.
class SneakerLoader extends StatefulWidget {
  final String? text;
  final double size;
  const SneakerLoader({super.key, this.text, this.size = 56});

  @override
  State<SneakerLoader> createState() => _SneakerLoaderState();
}

class _SneakerLoaderState extends State<SneakerLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = math.sin(_c.value * math.pi); // 0 → 1 → 0
            return SizedBox(
              width: widget.size * 1.6,
              height: widget.size * 1.5,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: widget.size * (0.9 - 0.4 * t),
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15 - 0.08 * t),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Positioned(
                    bottom: 6 + widget.size * 0.45 * t,
                    child: Transform.rotate(
                      angle: -0.25 + 0.5 * _c.value,
                      child: ShaderMask(
                        shaderCallback: (r) => AppColors.brandGradient.createShader(r),
                        child: Icon(Icons.directions_run_rounded, size: widget.size, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppStyles.gapS),
        _Dots(controller: _c),
        if (widget.text != null) ...[
          const SizedBox(height: AppStyles.gapS),
          Text(widget.text!, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  final AnimationController controller;
  const _Dots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final v = (math.sin((controller.value - i * 0.2) * 2 * math.pi) + 1) / 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.3 + 0.7 * v),
            ),
          );
        }),
      ),
    );
  }
}

/// Мерцающая заглушка («скелетон») на время загрузки данных.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    final base = dark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final light = dark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: [base, light, base],
          stops: const [0.35, 0.5, 0.65],
          begin: Alignment(-1 - 2 + 4 * _c.value, -0.3),
          end: Alignment(1 - 2 + 4 * _c.value, 0.3),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

/// Скелетон карточки товара.
class ShoeCardSkeleton extends StatelessWidget {
  const ShoeCardSkeleton({super.key});

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: 132,
        padding: AppStyles.cardPadding,
        decoration: BoxDecoration(
          borderRadius: AppStyles.cardRadius,
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          children: [
            Container(
              width: 128,
              decoration: BoxDecoration(color: Colors.white, borderRadius: AppStyles.cardRadius),
            ),
            const SizedBox(width: AppStyles.gapL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bar(60, 10),
                  const SizedBox(height: 10),
                  _bar(180, 16),
                  const SizedBox(height: 10),
                  _bar(120, 12),
                  const SizedBox(height: 16),
                  _bar(90, 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Список скелетонов для первой загрузки.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppStyles.screenPadding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppStyles.gapM),
      itemBuilder: (_, _) => const ShoeCardSkeleton(),
    );
  }
}
