import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/comment.dart';

class CommentsRepository {
  final ApiClient api;

  CommentsRepository(this.api);

  Future<List<CommentModel>> list(String taskId) async {
    final r = await api.dio.get('/tasks/$taskId/comments');
    return asMapList(r.data).map(CommentModel.fromJson).toList();
  }

  Future<CommentModel> create(String taskId, String content) async {
    final r = await api.dio.post('/tasks/$taskId/comments', data: {'content': content});
    return CommentModel.fromJson(asMap(r.data));
  }
}
