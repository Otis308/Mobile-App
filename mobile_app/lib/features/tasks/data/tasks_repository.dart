import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/task.dart';

class TasksRepository {
  final ApiClient api;

  TasksRepository(this.api);

  Future<List<TaskModel>> list(String projectId) async {
    final r = await api.dio.get('/projects/$projectId/tasks');
    return asMapList(r.data).map(TaskModel.fromJson).toList();
  }

  Future<TaskModel> create(String projectId, Map<String, dynamic> data) async {
    final r = await api.dio.post('/projects/$projectId/tasks', data: data);
    return TaskModel.fromJson(asMap(r.data));
  }

  Future<TaskModel> update(String id, Map<String, dynamic> data) async {
    final r = await api.dio.patch('/tasks/$id', data: data);
    return TaskModel.fromJson(asMap(r.data));
  }

  Future<TaskModel> move(String id, String status, int order) async {
    final r = await api.dio.patch('/tasks/$id/move', data: {'status': status, 'order': order});
    return TaskModel.fromJson(asMap(r.data));
  }

  Future<TaskModel> get(String id) async {
    final r = await api.dio.get('/tasks/$id');
    return TaskModel.fromJson(asMap(r.data));
  }

  Future<void> delete(String id) async {
    await api.dio.delete('/tasks/$id');
  }
}
