import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../styles/app_styles.dart';

/// Приветственный экран с анимацией. Пока идёт анимация,
/// в фоне восстанавливается сохранённый сеанс пользователя.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
  );
  late final Animation<double> _titleFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
  );
  late final Animation<double> _subtitleFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([auth.tryRestoreSession(), Future.delayed(const Duration(milliseconds: 2600))]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AppStyles.slow,
        pageBuilder: (_, _, _) => const AuthGate(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Stack(
          children: [
            // Движущиеся «беговые дорожки» на фоне
            AnimatedBuilder(
              animation: _loop,
              builder: (_, _) => CustomPaint(size: Size.infinite, painter: _TrackPainter(_loop.value)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _logoScale,
                    child: AnimatedBuilder(
                      animation: _loop,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, -8 * math.sin(_loop.value * 2 * math.pi * 2).abs()),
                        child: child,
                      ),
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 40,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.directions_run_rounded, size: 76, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppStyles.gapXL),
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(_titleFade),
                      child: const Text('SPORT STEP', style: AppStyles.logo),
                    ),
                  ),
                  const SizedBox(height: AppStyles.gapS),
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: const Text(
                      'Каталог спортивной обуви',
                      style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: AppStyles.gapXXL),
                  SizedBox(
                    width: 180,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress.value,
                          minHeight: 5,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Рисует диагональные полосы, «убегающие» справа налево.
class _TrackPainter extends CustomPainter {
  final double t;
  _TrackPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final y = rnd.nextDouble() * size.height;
      final len = 40 + rnd.nextDouble() * 120;
      final speed = 0.5 + rnd.nextDouble();
      final x = size.width - ((t * speed + rnd.nextDouble()) % 1.0) * (size.width + len * 2) + len;
      paint.color = Colors.white.withValues(alpha: 0.04 + rnd.nextDouble() * 0.08);
      canvas.drawLine(Offset(x, y), Offset(x + len, y), paint);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.t != t;
}
