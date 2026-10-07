import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../domain/entities/task.dart';
import 'task_detail_page.dart';
import 'task_providers.dart';

const _statuses = ['todo', 'doing', 'review', 'done'];

class _NewTaskDialog extends StatefulWidget {
  const _NewTaskDialog();

  @override
  State<_NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<_NewTaskDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _priority = 'medium';

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo công việc'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tiêu đề (2-180 ký tự)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            const SizedBox(height: 10),
            LabeledDropdown<String>(
              label: 'Độ ưu tiên',
              value: _priority,
              items: [
                for (final e in taskPriorityLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 'medium'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(<String, dynamic>{
            'title': _title.text.trim(),
            'description': _desc.text.trim(),
            'priority': _priority,
            'status': 'todo',
          }),
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

class KanbanPage extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;

  const KanbanPage({super.key, required this.projectId, required this.projectName});

  @override
  ConsumerState<KanbanPage> createState() => _KanbanPageState();
}

class _KanbanPageState extends ConsumerState<KanbanPage> {
  late final SocketService _socket;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _sub = _socket.events.listen((event) {
      if (!mounted) return;
      if (event.name.startsWith('task.')) {
        ref.invalidate(tasksProvider(widget.projectId));
      }
    });
    _connect();
  }

  Future<void> _connect() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (!mounted || token == null) return;
    _socket.connect(token);
    _socket.joinProject(widget.projectId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _socket.disconnect();
    super.dispose();
  }

  void _refresh() => ref.invalidate(tasksProvider(widget.projectId));

  Future<void> _move(TaskModel task, String status, int order) async {
    if (task.status == status) return;
    try {
      await ref.read(tasksRepositoryProvider).move(task.id, status, order);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
    if (mounted) _refresh();
  }

  Future<void> _newTask() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _NewTaskDialog(),
    );
    if (data == null) return;
    if ((data['title'] as String).length < 2) {
      if (mounted) showSnack(context, 'Tiêu đề cần ít nhất 2 ký tự');
      return;
    }
    if ((data['description'] as String).isEmpty) data.remove('description');
    try {
      await ref.read(tasksRepositoryProvider).create(widget.projectId, data);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
    if (mounted) _refresh();
  }

  void _openTask(TaskModel t) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => TaskDetailPage(taskId: t.id)))
        .then((_) {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          IconButton(
            tooltip: 'Tạo công việc',
            onPressed: _newTask,
            icon: const Icon(Icons.add_task),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tasksProvider(widget.projectId).future),
        child: tasks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(error: e, onRetry: _refresh),
          data: (items) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final s in _statuses) _column(context, s, items)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _column(BuildContext context, String status, List<TaskModel> tasks) {
    final items = tasks.where((t) => t.status == status).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return DragTarget<TaskModel>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) => _move(details.data, status, items.length),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: 290,
          constraints: const BoxConstraints(minHeight: 160),
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlight ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    taskStatusLabels[status] ?? status,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  CircleAvatar(radius: 13, child: Text('${items.length}')),
                ],
              ),
              const SizedBox(height: 10),
              for (final t in items) _draggableCard(context, t),
            ],
          ),
        );
      },
    );
  }

  Widget _draggableCard(BuildContext context, TaskModel t) {
    return LongPressDraggable<TaskModel>(
      data: t,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 270, child: _taskTile(context, t, dragging: true)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _taskTile(context, t)),
      child: _taskTile(context, t),
    );
  }

  Widget _taskTile(BuildContext context, TaskModel t, {bool dragging = false}) {
    final textTheme = Theme.of(context).textTheme;
    final due = t.due;

    return Card(
      elevation: dragging ? 6 : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: dragging ? null : () => _openTask(t),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (t.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          t.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _priorityChip(context, t.priority),
                        if (due != null)
                          Text('Hạn ${DateFormat('dd/MM').format(due)}', style: textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
              if (!dragging)
                PopupMenuButton<String>(
                  tooltip: 'Chuyển trạng thái',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (status) => _move(t, status, 9999),
                  itemBuilder: (_) => [
                    for (final s in _statuses)
                      if (s != t.status)
                        PopupMenuItem(
                          value: s,
                          child: Text('Chuyển sang: ${taskStatusLabels[s]}'),
                        ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityChip(BuildContext context, String p) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        taskPriorityLabels[p] ?? p,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}
