class AppConstants {
  AppConstants._();

  static const appName = 'WorkFlow';

  /// Có thể ghi đè khi build:
  /// flutter build apk --dart-define=API_BASE_URL=https://example.com/api
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    //Sử dụng cho render
    defaultValue: 'https://mobile-app-u103.onrender.com/api',
    //Sử dụng cho local
    //defaultValue: 'http://localhost:3000/api',
  );

  /// Socket.IO của backend nằm ở namespace `/realtime`.
  static const socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://mobile-app-u103.onrender.com/realtime',
  );

  /// Địa chỉ gốc của server (dùng để ghép đường dẫn ảnh `/uploads/...`).
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
