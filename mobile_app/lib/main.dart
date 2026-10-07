import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/auth/presentation/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  try {
    await container.read(authControllerProvider.notifier).restoreSession();
  } catch (_) {
    // Không có phiên cũ hoặc không kết nối được -> hiện màn hình đăng nhập.
  }

  runApp(UncontrolledProviderScope(container: container, child: const WorkflowApp()));
}
