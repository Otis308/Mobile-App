import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _login = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).login(_login.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Icon(Icons.task_alt_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _login,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Username hoặc Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
              ),
              if (s.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(s.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (s.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Đang kết nối máy chủ, lần đầu có thể mất khoảng 1 phút...',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              AppButton(label: 'Đăng nhập', loading: s.loading, onPressed: _submit),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).clearError();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                  );
                },
                child: const Text('Chưa có tài khoản? Đăng ký ngay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).register(
          _email.text.trim(),
          _username.text.trim(),
          _fullName.text.trim(),
          _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Đăng ký thành công -> đóng trang này để màn hình chính (HomeShell) hiện ra.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.isAuthenticated) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final s = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _fullName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Username (chữ, số, _ . -)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Mật khẩu (tối thiểu 8 ký tự)'),
              ),
              if (s.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(s.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 16),
              AppButton(label: 'Đăng ký', loading: s.loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
