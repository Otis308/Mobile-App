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

  AuthRepository(this.api, this.storage);

  Future<AuthResult> login(String login, String password) async {
    final r = await api.dio.post('/auth/login', data: {'login': login, 'password': password});
    return _handle(r.data);
  }

  Future<AuthResult> register(
    String email,
    String username,
    String fullName,
    String password,
  ) async {
    final r = await api.dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'fullName': fullName,
      'password': password,
    });
    return _handle(r.data);
  }

  Future<UserModel> me() async {
    final r = await api.dio.get('/users/me');
    return UserModel.fromJson(asMap(r.data));
  }

  Future<void> logout() => storage.clear();

  Future<AuthResult> _handle(dynamic raw) async {
    final data = asMap(raw);
    final token = data['accessToken'].toString();
    await storage.save(token);
    return AuthResult(token, UserModel.fromJson(asMap(data['user'])));
  }
}
