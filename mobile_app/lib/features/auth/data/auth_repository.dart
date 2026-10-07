import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/user.dart';

class AuthResult {
  final String token;
  final UserModel user;
  const AuthResult(this.token, this.user);
}

class AuthRepository {
  final ApiClient api;
  final TokenStorage storage;

  // Đã sửa: Constructor chỉ nhận 2 tham số (khớp 100% với auth_controller.dart)
  AuthRepository(this.api, this.storage);

  Future<AuthResult> login(String login, String password) async {
    final r = await api.dio.post('/auth/login', data: {'login': login, 'password': password});
    return _handle(r.data);
  }

  Future<AuthResult> register(
    String fullName,
    String username,
    String phone,
    String email,
    String dob,
    String gender,
    String password,
  ) async {
    final res = await api.dio.post('/auth/register', data: {
      'fullName': fullName,
      'username': username,
      'phone': phone,
      'email': email,
      'dob': dob,
      'gender': gender,
      'password': password,
    });
    
    // Gọi thẳng hàm _handle để xử lý parse dữ liệu và lưu token
    return _handle(res.data);
  }

  Future<UserModel> me() async {
    final r = await api.dio.get('/users/me');
    return UserModel.fromJson(asMap(r.data));
  }

  Future<void> logout() async {
    await storage.clear();
  }

  Future<AuthResult> _handle(dynamic raw) async {
    final data = asMap(raw);
    final token = data['accessToken'].toString();
    await storage.save(token);
    return AuthResult(token, UserModel.fromJson(asMap(data['user'])));
  }

  //Hàm API Quên mật khẩu
  Future<void> requestOtp(String email) async {
    await api.dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> verifyOtp(String email, String otp) async {
    await api.dio.post('/auth/verify-otp', data: {'email': email, 'otp': otp});
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    await api.dio.post('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
  }
}
