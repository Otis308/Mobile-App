import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_states.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/presentation/task_detail_page.dart';
import '../../tasks/presentation/task_providers.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(allTasksProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(allTasksProvider.future),
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(allTasksProvider)),
        data: (all) {
          final tasks = [...all]..sort((a, b) {
              final da = a.due;
              final db = b.due;
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              return da.compareTo(db);
            });

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Lịch biểu',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Theo dõi các deadline của toàn bộ dự án bạn tham gia.'),
              const SizedBox(height: 20),
              if (tasks.isEmpty) const Text('Chưa có công việc nào.'),
              for (final t in tasks) _tile(context, t),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, TaskModel t) {
    final due = t.due;
    final overdue = due != null && t.status != 'done' && due.isBefore(DateTime.now());

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(t.status == 'done' ? Icons.check : Icons.event)),
        title: Text(t.title),
        subtitle: Text(
          due == null ? 'Chưa có deadline' : DateFormat('dd/MM/yyyy HH:mm').format(due),
          style: overdue ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
        ),
        trailing: Text(taskStatusLabels[t.status] ?? t.status),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TaskDetailPage(taskId: t.id)),
        ),
      ),
    );
  }
}
