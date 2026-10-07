import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/projects_repository.dart';
import '../domain/entities/project.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ProjectsRepository(ref.read(apiClientProvider)),
);

final projectsProvider = FutureProvider.autoDispose<List<ProjectModel>>(
  (ref) => ref.read(projectsRepositoryProvider).list(),
);

final projectMembersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, id) => ref.read(projectsRepositoryProvider).members(id),
);
