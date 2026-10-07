import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _key = 'access_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // Không để lỗi keystore làm hỏng luồng đăng nhập.
    }
  }

  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
