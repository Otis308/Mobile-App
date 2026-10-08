import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/dashboard.dart';

class DashboardRepository {
  final ApiClient api;

  DashboardRepository(this.api);

  Future<DashboardModel> getSummary() async {
    final r = await api.dio.get('/dashboard');
    return DashboardModel.fromJson(asMap(r.data));
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final r = await api.dio.get('/notifications');
    return asMapList(r.data);
  }

  Future<void> markRead(String id) async {
    await api.dio.patch('/notifications/$id/read');
  }
  Future<void> markAllRead() async {
    await api.dio.patch('/notifications/read-all');
  }
}
