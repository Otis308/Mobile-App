import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_states.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/presentation/due_utils.dart';
import '../../tasks/presentation/task_detail_page.dart';

class TaskDueTile extends StatelessWidget {
  final TaskModel task;
  final String projectName;

  const TaskDueTile({super.key, required this.task, required this.projectName});

  @override
  Widget build(BuildContext context) {
    final state = dueStateOf(task);
    final color = dueColor(context, state);
    final due = task.due;
    final prefix = projectName.isEmpty ? '' : '$projectName • ';
    final when = due == null ? 'Chưa có deadline' : DateFormat('dd/MM/yyyy HH:mm').format(due);

    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(40),
          child: Icon(state == DueState.done ? Icons.check : Icons.event, color: color),
        ),
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('$prefix$when\n${dueLabel(task)}', style: TextStyle(color: color)),
        trailing: Text(taskStatusLabels[task.status] ?? task.status),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TaskDetailPage(taskId: task.id)),
        ),
      ),
    );
  }
}

class DeadlineList extends StatelessWidget {
  final List<TaskModel> tasks;
  final Map<String, String> projectNames;

  const DeadlineList({super.key, required this.tasks, required this.projectNames});

  static const _order = [
    DueState.overdue,
    DueState.today,
    DueState.soon,
    DueState.later,
    DueState.none,
  ];
  static const _titles = {
    DueState.overdue: 'Quá hạn',
    DueState.today: 'Hôm nay',
    DueState.soon: '3 ngày tới',
    DueState.later: 'Sau đó',
    DueState.none: 'Chưa có deadline',
  };

  int _cmp(TaskModel a, TaskModel b) {
    final da = a.due;
    final db = b.due;
    if (da == null && db == null) return a.title.compareTo(b.title);
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <DueState, List<TaskModel>>{
      for (final s in DueState.values) s: <TaskModel>[],
    };
    for (final t in tasks) {
      groups[dueStateOf(t)]!.add(t);
    }

    final children = <Widget>[
      Text(
        'Deadline',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    ];
    for (final s in _order) {
      final list = groups[s]!..sort(_cmp);
      if (list.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            '${_titles[s]} (${list.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: dueColor(context, s),
                ),
          ),
        ),
      );
      for (final t in list) {
        children.add(TaskDueTile(task: t, projectName: projectNames[t.projectId] ?? ''));
      }
    }
    final done = groups[DueState.done]!.length;
    if (children.length == 1) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Không có công việc nào cần theo dõi.')),
      ));
    }
    if (done > 0) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text('Đã hoàn tất: $done công việc', style: Theme.of(context).textTheme.bodySmall),
      ));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}