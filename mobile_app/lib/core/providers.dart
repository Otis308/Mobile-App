import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'network/socket_service.dart';
import 'storage/token_storage.dart';
import '../features/auth/presentation/auth_controller.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.read(tokenStorageProvider));
  client.onUnauthorized = () => ref.read(authControllerProvider.notifier).sessionExpired();
  return client;
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});
