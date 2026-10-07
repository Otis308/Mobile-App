import 'package:dio/dio.dart';

class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Chuyển mọi lỗi (Dio, AppException, ...) thành câu thông báo ngắn gọn cho người dùng.
String errorMessage(Object error) {
  if (error is AppException) return error.message;
  if (error is DioException) {
    final inner = error.error;
    if (inner is AppException) return inner.message;
    return 'Không thể kết nối máy chủ';
  }
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
