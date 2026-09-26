import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../styles/app_styles.dart';
import '../widgets/common.dart';

/// Регистрация нового клиента.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _agree = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _login, _password, _password2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      showMessage(context, 'Подтвердите согласие с правилами сервиса', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(_login.text, _password.text, _name.text);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppStyles.gapXL),
        child: ContentWidth(
          maxWidth: 480,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Создайте аккаунт клиента, чтобы добавлять модели в избранное, '
                  'оставлять отзывы и бронировать обувь.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppStyles.gapXL),
                TextFormField(
                  controller: _name,
                  decoration: AppStyles.input('Имя и фамилия', icon: Icons.badge_outlined),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Введите имя (минимум 2 символа)' : null,
                ),
                const SizedBox(height: AppStyles.gapL),
                TextFormField(
                  controller: _login,
                  decoration: AppStyles.input('Логин', icon: Icons.person_outline, hint: 'латиница, от 3 символов'),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.length < 3) return 'Логин должен содержать минимум 3 символа';
                    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(t)) return 'Допустимы латинские буквы, цифры, «_» и «.»';
                    return null;
                  },
                ),
                const SizedBox(height: AppStyles.gapL),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: AppStyles.input('Пароль', icon: Icons.lock_outline),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.length < 6) ? 'Пароль должен содержать минимум 6 символов' : null,
                ),
                const SizedBox(height: AppStyles.gapL),
                TextFormField(
                  controller: _password2,
                  obscureText: true,
                  decoration: AppStyles.input('Повторите пароль', icon: Icons.lock_outline),
                  validator: (v) => v != _password.text ? 'Пароли не совпадают' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppStyles.gapS),
                CheckboxListTile(
                  value: _agree,
                  onChanged: (v) => setState(() => _agree = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Я согласен с правилами сервиса'),
                ),
                const SizedBox(height: AppStyles.gapL),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Создать аккаунт'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
