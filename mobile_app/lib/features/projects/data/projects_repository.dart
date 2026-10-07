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

  Future<ProjectModel> create(String name, String description) async {
    final r = await api.dio.post('/projects', data: {
      'name': name,
      if (description.isNotEmpty) 'description': description,
    });
    return ProjectModel.fromJson(asMap(r.data));
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
}
