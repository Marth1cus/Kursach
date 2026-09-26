import 'package:flutter/material.dart';

/// Цветовая палитра приложения.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFF5A1F); // «спортивный» оранжевый
  static const Color primaryDark = Color(0xFFE63F00);
  static const Color secondary = Color(0xFF1E2A78); // глубокий синий
  static const Color navy = Color(0xFF0F172A);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color star = Color(0xFFFFB400);
  static const Color favorite = Color(0xFFE11D48);

  static const Color lightBackground = Color(0xFFF5F6FA);
  static const Color lightSurface = Colors.white;
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF151E32);

  static const Color textMuted = Color(0xFF64748B);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFF7A2F), Color(0xFFFF3D54)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E2A78)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Отступы, скругления, тени, стили текста и темы приложения.
class AppStyles {
  AppStyles._();

  // Отступы
  static const double gapXS = 4;
  static const double gapS = 8;
  static const double gapM = 12;
  static const double gapL = 16;
  static const double gapXL = 24;
  static const double gapXXL = 32;

  static const EdgeInsets screenPadding = EdgeInsets.all(gapL);
  static const EdgeInsets cardPadding = EdgeInsets.all(gapM);

  /// Максимальная ширина контента — чтобы на широком экране браузера
  /// интерфейс не растягивался на всю ширину.
  static const double maxContentWidth = 900;

  // Скругления
  static const double radiusS = 8;
  static const double radiusM = 14;
  static const double radiusL = 22;
  static final BorderRadius cardRadius = BorderRadius.circular(radiusM);
  static final BorderRadius buttonRadius = BorderRadius.circular(radiusS + 4);

  // Тени
  static List<BoxShadow> cardShadow(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark(context) ? 0.35 : 0.07),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  // Длительности анимаций
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 700);

  // Текст
  static const TextStyle logo = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    letterSpacing: 2,
    color: Colors.white,
  );
  static const TextStyle price = TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary);
  static const TextStyle oldPrice = TextStyle(
    fontSize: 13,
    color: AppColors.textMuted,
    decoration: TextDecoration.lineThrough,
  );
  static const TextStyle brand = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );
  static const TextStyle sectionTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);

  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static InputDecoration input(String label, {IconData? icon, String? hint}) =>
      InputDecoration(labelText: label, hintText: hint, prefixIcon: icon != null ? Icon(icon) : null);

  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
    );
    final border = OutlineInputBorder(
      borderRadius: buttonRadius,
      borderSide: BorderSide(color: dark ? Colors.white24 : Colors.black12),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? AppColors.darkBackground : AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.darkSurface : Colors.white,
        foregroundColor: dark ? Colors.white : AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: dark ? Colors.white : AppColors.navy,
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.danger)),
        contentPadding: const EdgeInsets.symmetric(horizontal: gapL, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        ),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS))),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// Справочники категорий и их оформление.
class ShoeCategories {
  ShoeCategories._();

  static const Map<String, String> labels = {
    'running': 'Бег',
    'basketball': 'Баскетбол',
    'football': 'Футбол',
    'training': 'Тренинг',
    'tennis': 'Теннис',
    'trail': 'Трейл',
    'lifestyle': 'Лайфстайл',
    'volleyball': 'Волейбол',
  };

  static const Map<String, IconData> icons = {
    'running': Icons.directions_run,
    'basketball': Icons.sports_basketball,
    'football': Icons.sports_soccer,
    'training': Icons.fitness_center,
    'tennis': Icons.sports_tennis,
    'trail': Icons.terrain,
    'lifestyle': Icons.local_mall_outlined,
    'volleyball': Icons.sports_volleyball,
  };

  static const Map<String, Color> colors = {
    'running': Color(0xFFFF5A1F),
    'basketball': Color(0xFFEA580C),
    'football': Color(0xFF16A34A),
    'training': Color(0xFF7C3AED),
    'tennis': Color(0xFF0EA5E9),
    'trail': Color(0xFF65A30D),
    'lifestyle': Color(0xFFDB2777),
    'volleyball': Color(0xFF2563EB),
  };

  static String label(String key) => labels[key] ?? key;
  static IconData icon(String key) => icons[key] ?? Icons.category;
  static Color color(String key) => colors[key] ?? AppColors.primary;
}

class Genders {
  Genders._();
  static const Map<String, String> labels = {'men': 'Мужские', 'women': 'Женские', 'unisex': 'Унисекс'};
  static String label(String key) => labels[key] ?? key;
}
