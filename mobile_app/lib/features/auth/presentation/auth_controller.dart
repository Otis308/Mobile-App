import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/entities/user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(apiClientProvider), ref.read(tokenStorageProvider)),
);

class AuthState {
  final UserModel? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  bool get isAuthenticated => user != null;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> restoreSession() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.read();
    if (token == null || token.isEmpty) {
      state = const AuthState();
      return;
    }
    try {
      final user = await _repo.me();
      state = AuthState(user: user);
    } catch (_) {
      await storage.clear();
      state = const AuthState();
    }
  }

  Future<void> login(String login, String password) async {
    if (login.isEmpty || password.isEmpty) {
      state = const AuthState(error: 'Vui lòng nhập đầy đủ thông tin');
      return;
    }
    state = const AuthState(loading: true);
    try {
      final r = await _repo.login(login, password);
      state = AuthState(user: r.user);
    } catch (e) {
      state = AuthState(error: errorMessage(e));
    }
  }

  Future<void> register(
    String email,
    String username,
    String fullName,
    String password,
  ) async {
    if (email.isEmpty || username.isEmpty || fullName.isEmpty || password.isEmpty) {
      state = const AuthState(error: 'Vui lòng nhập đầy đủ thông tin');
      return;
    }
    state = const AuthState(loading: true);
    try {
      final r = await _repo.register(email, username, fullName, password);
      state = AuthState(user: r.user);
    } catch (e) {
      state = AuthState(error: errorMessage(e));
    }
  }

  /// Tải lại thông tin người dùng (sau khi sửa hồ sơ) mà không làm đăng xuất khi lỗi mạng.
  Future<void> refreshUser() async {
    try {
      final user = await _repo.me();
      state = AuthState(user: user);
    } catch (_) {}
  }

  void clearError() {
    if (state.error != null) state = AuthState(user: state.user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
