import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';

class TeamRepository {
  final ApiClient api;

  TeamRepository(this.api);

  Future<List<Map<String, dynamic>>> search(String q) async {
    final r = await api.dio.get('/users/search', queryParameters: {'q': q});
    return asMapList(r.data);
  }
}
