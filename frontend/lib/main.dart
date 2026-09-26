import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'styles/app_styles.dart';
import 'widgets/common.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = ThemeProvider();
  await theme.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider.value(value: theme),
      ],
      child: const ShoeCatalogApp(),
    ),
  );
}

class ShoeCatalogApp extends StatelessWidget {
  const ShoeCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Каталог спортивной обуви',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: AppStyles.lightTheme,
      darkTheme: AppStyles.darkTheme,
      themeMode: theme.mode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}

/// Выбирает экран по состоянию авторизации. Интерфейс (клиент/администратор)
/// определяется ролью, которую вернул сервер, — без ручного выбора роли.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _wasLoggedIn;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loggedIn = auth.isLoggedIn;

    if (_wasLoggedIn != loggedIn) {
      final previous = _wasLoggedIn;
      _wasLoggedIn = loggedIn;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifications = context.read<NotificationProvider>();
        if (loggedIn) {
          notifications.start();
        } else {
          notifications.stop();
          if (previous == true) {
            // Закрываем все открытые экраны и возвращаемся ко входу.
            navigatorKey.currentState?.popUntil((r) => r.isFirst);
            final msg = auth.takeSessionMessage();
            final ctx = messengerKey.currentContext;
            if (msg != null && ctx != null) showMessage(ctx, msg, error: true);
          }
        }
      });
    }

    return AnimatedSwitcher(
      duration: AppStyles.normal,
      child: loggedIn ? HomeScreen(key: ValueKey('home-${auth.user!.id}')) : const LoginScreen(key: ValueKey('login')),
    );
  }
}
