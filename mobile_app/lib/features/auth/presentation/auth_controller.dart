import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/entities/user.dart';
import '../../../core/realtime/presence_provider.dart';

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
    String fullName,
    String username,
    String phone,
    String email,
    String dob,
    String gender,
    String password,
  ) async {
    if (email.isEmpty || username.isEmpty || fullName.isEmpty || password.isEmpty) {
      state = const AuthState(error: 'Vui lòng nhập đầy đủ thông tin');
      return;
    }
    state = const AuthState(loading: true);
    try {
      final r = await _repo.register(
        fullName,
        username,
        phone,
        email,
        dob,
        gender,
        password,
      );
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
    ref.invalidate(presenceProvider);
    state = const AuthState();
  }

  // Xử lý luồng Quên mật khẩu (Trả về chuỗi lỗi, nếu null là thành công)
  Future<String?> requestOtp(String email) async {
    try {
      await _repo.requestOtp(email);
      return null;
    } catch (e) {
      return errorMessage(e);
    }
  }

  Future<String?> verifyOtp(String email, String otp) async {
    try {
      await _repo.verifyOtp(email, otp);
      return null;
    } catch (e) {
      return errorMessage(e);
    }
  }

  Future<String?> resetPassword(String email, String otp, String newPassword) async {
    try {
      await _repo.resetPassword(email, otp, newPassword);
      return null;
    } catch (e) {
      return errorMessage(e);
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
