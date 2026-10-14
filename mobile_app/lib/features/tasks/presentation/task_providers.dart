// File: mobile_app/lib/features/tasks/presentation/task_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../projects/presentation/project_providers.dart';
import '../data/comments_repository.dart';
import '../data/tasks_repository.dart';
import '../domain/entities/comment.dart';
import '../domain/entities/task.dart';

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.read(apiClientProvider)),
);

final commentsRepositoryProvider = Provider<CommentsRepository>(
  (ref) => CommentsRepository(ref.read(apiClientProvider)),
);

final tasksProvider = FutureProvider.autoDispose.family<List<TaskModel>, String>(
  (ref, projectId) => ref.read(tasksRepositoryProvider).list(projectId),
);

final taskProvider = FutureProvider.autoDispose.family<TaskModel, String>(
  (ref, id) => ref.read(tasksRepositoryProvider).get(id),
);

final commentsProvider = FutureProvider.autoDispose.family<List<CommentModel>, String>(
  (ref, taskId) => ref.read(commentsRepositoryProvider).list(taskId),
);

/// Lấy toàn bộ công việc của mọi dự án qua 1 request /tasks/mine (kèm fallback nếu backend chưa cập nhật).
final allTasksProvider = FutureProvider.autoDispose<List<TaskModel>>((ref) async {
  final repo = ref.read(tasksRepositoryProvider);
  try {
    return await repo.listMine();
  } catch (_) {
    final projects = await ref.watch(projectsProvider.future);
    final lists = await Future.wait(projects.map((p) => repo.list(p.id)));
    return [for (final l in lists) ...l];
  }
});