// File: mobile_app/lib/core/constants/app_constants.dart
class AppConstants {
  AppConstants._();

  static const appName = 'WorkFlow';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Để mặc định là Render để khi GitHub Actions build APK các máy điện thoại dùng chung được ngay
    defaultValue: 'https://mobile-app-u103.onrender.com/api',
    // Khi test ở máy local bằng F5 thì tạm đổi thành:
    // defaultValue: 'http://localhost:3000/api',
  );

  static const _envSocketUrl = String.fromEnvironment('SOCKET_URL');

  /// Tự động lấy cùng host với apiBaseUrl + '/realtime'
  static String get socketUrl =>
      _envSocketUrl.isNotEmpty ? _envSocketUrl : '$serverOrigin/realtime';

  static String get serverOrigin {
    var base = apiBaseUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return base;
  }

  static String resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$serverOrigin${path.startsWith('/') ? '' : '/'}$path';
  }
}