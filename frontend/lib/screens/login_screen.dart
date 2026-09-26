import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../styles/app_styles.dart';
import 'register_screen.dart';

/// Экран входа. Выбора роли нет: сервер сам определяет,
/// кто вошёл — клиент или администратор.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    StorageService.getLastLogin().then((v) {
      if (v != null && mounted && _login.text.isEmpty) _login.text = v;
    });
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_login.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyles.gapXL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const _Logo(),
                  const SizedBox(height: AppStyles.gapXXL),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppStyles.gapXL),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Вход', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: AppStyles.gapXS),
                            const Text('Войдите, чтобы открыть каталог', style: TextStyle(color: AppColors.textMuted)),
                            const SizedBox(height: AppStyles.gapXL),
                            TextFormField(
                              controller: _login,
                              decoration: AppStyles.input('Логин', icon: Icons.person_outline),
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите логин' : null,
                            ),
                            const SizedBox(height: AppStyles.gapL),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              decoration: AppStyles.input('Пароль', icon: Icons.lock_outline).copyWith(
                                suffixIcon: IconButton(
                                  tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
                                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Введите пароль' : null,
                            ),
                            AnimatedSize(
                              duration: AppStyles.fast,
                              child: _error == null
                                  ? const SizedBox(height: AppStyles.gapXL)
                                  : Container(
                                      margin: const EdgeInsets.symmetric(vertical: AppStyles.gapL),
                                      padding: const EdgeInsets.all(AppStyles.gapM),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppStyles.radiusS),
                                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: AppColors.danger),
                                          const SizedBox(width: AppStyles.gapS),
                                          Expanded(
                                            child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : const Text('Войти'),
                            ),
                            const SizedBox(height: AppStyles.gapM),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    ),
                              child: const Text('Нет аккаунта? Зарегистрироваться'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppStyles.gapL),
                  const _DemoHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.directions_run_rounded, color: Colors.white, size: 52),
      ),
      const SizedBox(height: AppStyles.gapM),
      const Text('SPORT STEP', style: AppStyles.logo),
      const Text('Каталог спортивной обуви', style: TextStyle(color: Colors.white70)),
    ],
  );
}

/// Подсказка с тестовыми учётными записями.
class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppStyles.gapM),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppStyles.radiusM),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: Colors.white70, size: 20),
        SizedBox(width: AppStyles.gapM),
        Expanded(
          child: Text(
            'Тестовые аккаунты:\nадминистратор — admin / admin123\nклиент — client / client123',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
