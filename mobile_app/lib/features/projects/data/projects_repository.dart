import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/project.dart';

class ProjectsRepository {
  final ApiClient api;

  ProjectsRepository(this.api);

  Future<List<ProjectModel>> list() async {
    final r = await api.dio.get('/projects');
    return asMapList(r.data).map(ProjectModel.fromJson).toList();
  }

  Future<ProjectModel> create(String name, String description, {String? color}) async {
    final r = await api.dio.post('/projects', data: {
      'name': name,
      if (description.isNotEmpty) 'description': description,
      if (color != null) 'color': color,
    });
    return ProjectModel.fromJson(asMap(r.data));
  }

  Future<void> update(String id, {String? name, String? description, String? color}) async {
    await api.dio.put('/projects/$id', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (color != null) 'color': color,
    });
  }

  Future<void> delete(String id) async {
    await api.dio.delete('/projects/$id');
  }

  Future<ProjectModel> get(String id) async {
    final r = await api.dio.get('/projects/$id');
    return ProjectModel.fromJson(asMap(r.data));
  }

  Future<List<Map<String, dynamic>>> members(String id) async {
    final r = await api.dio.get('/projects/$id/members');
    return asMapList(r.data);
  }

  Future<void> addMember(String projectId, String userId, String role) async {
    await api.dio.post('/projects/$projectId/members', data: {'userId': userId, 'role': role});
  }

  Future<void> updateMemberRole(String projectId, String userId, String role) async {
    await api.dio.patch('/projects/$projectId/members/$userId', data: {'role': role});
  }

  Future<void> removeMember(String projectId, String userId) async {
    await api.dio.delete('/projects/$projectId/members/$userId');
  }
}
