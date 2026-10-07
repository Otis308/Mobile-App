import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/entities/dashboard.dart';
import 'dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.read(apiClientProvider)),
);

final dashboardProvider = FutureProvider.autoDispose<DashboardModel>(
  (ref) => ref.read(dashboardRepositoryProvider).getSummary(),
);

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(dashboardRepositoryProvider).notifications(),
);
