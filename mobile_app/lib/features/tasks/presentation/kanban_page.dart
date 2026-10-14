import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../domain/entities/task.dart';
import 'due_utils.dart';
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
      title: const Text('Tạo công việc mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tiêu đề (2-180 ký tự)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả chi tiết'),
            ),
            const SizedBox(height: 12),
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
  String? _label;
  List<TaskModel>? _optimisticTasks;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _socket.joinProject(widget.projectId);
  }

  @override
  void dispose() {
    _socket.leaveProject(widget.projectId);
    super.dispose();
  }

  void _refresh() {
    setState(() => _optimisticTasks = null);
    ref.invalidate(tasksProvider(widget.projectId));
  }

  Future<void> _move(TaskModel task, String status, int order, List<TaskModel> currentAll) async {
    final updatedList = [...currentAll];
    final idx = updatedList.indexWhere((x) => x.id == task.id);
    if (idx != -1) {
      updatedList[idx] = task.copyWith(status: status, order: order);
      setState(() => _optimisticTasks = updatedList);
    }

    try {
      await ref.read(tasksRepositoryProvider).move(task.id, status, order);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) _refresh();
    }
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
    final tasksAsync = ref.watch(tasksProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: _newTask,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm việc'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _optimisticTasks = null);
          ref.invalidate(tasksProvider(widget.projectId));
          await ref.read(tasksProvider(widget.projectId).future);
        },
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(error: e, onRetry: _refresh),
          data: (serverTasks) {
            final all = _optimisticTasks ?? serverTasks;
            final labels = ({for (final t in all) ...t.labels}.toList()..sort());
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (labels.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: _label == null,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _label = null),
                          ),
                          for (final l in labels)
                            ChoiceChip(
                              label: Text('#$l'),
                              selected: _label == l,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() => _label = l),
                            ),
                        ],
                      ),
                    ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in _statuses) _column(context, s, all),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _column(BuildContext context, String status, List<TaskModel> all) {
    final full = all.where((t) => t.status == status).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final items = _label == null
        ? full
        : [
            for (final t in full)
              if (t.labels.contains(_label)) t,
          ];

    return DragTarget<TaskModel>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) =>
          _move(d.data, status, full.where((x) => x.id != d.data.id).length, all),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        final scheme = Theme.of(context).colorScheme;

        return Container(
          width: 284,
          constraints: const BoxConstraints(minHeight: 160),
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: highlight
                ? scheme.primaryContainer.withValues(alpha: 0.35)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.5),
              width: highlight ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      taskStatusLabels[status] ?? status.toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${items.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Trống',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              for (final t in items) _draggableCard(context, t, full, all),
            ],
          ),
        );
      },
    );
  }

  Widget _draggableCard(
    BuildContext context,
    TaskModel t,
    List<TaskModel> full,
    List<TaskModel> all,
  ) {
    return DragTarget<TaskModel>(
      onWillAcceptWithDetails: (d) => d.data.id != t.id,
      onAcceptWithDetails: (d) {
        final others = full.where((x) => x.id != d.data.id).toList();
        final targetIndex = others.indexWhere((x) => x.id == t.id);
        _move(d.data, t.status, targetIndex < 0 ? 0 : targetIndex, all);
      },
      builder: (context, candidate, rejected) => Column(
        children: [
          if (candidate.isNotEmpty)
            Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          LongPressDraggable<TaskModel>(
            data: t,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(width: 264, child: _taskTile(context, t, all, dragging: true)),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: _taskTile(context, t, all)),
            child: _taskTile(context, t, all),
          ),
        ],
      ),
    );
  }

  Widget _taskTile(
    BuildContext context,
    TaskModel t,
    List<TaskModel> all, {
    bool dragging = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final due = t.due;

    return Card(
      elevation: dragging ? 4 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: dragging ? null : () => _openTask(t),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (t.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          t.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _priorityChip(context, t.priority),
                        if (due != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: dueColor(context, dueStateOf(t)),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                DateFormat('dd/MM').format(due),
                                style: textTheme.labelSmall?.copyWith(
                                  color: dueColor(context, dueStateOf(t)),
                                  fontWeight:
                                      dueStateOf(t) == DueState.overdue ? FontWeight.w700 : null,
                                ),
                              ),
                            ],
                          ),
                        for (final l in t.labels.take(2))
                          Text(
                            '#$l',
                            style: textTheme.labelSmall?.copyWith(color: scheme.primary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!dragging)
                PopupMenuButton<String>(
                  tooltip: 'Chuyển trạng thái',
                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: scheme.onSurfaceVariant),
                  onSelected: (status) => _move(t, status, 9999, all),
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
    final Color bg;
    final Color fg;
    switch (p) {
      case 'urgent':
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        break;
      case 'high':
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange.shade800;
        break;
      default:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        taskPriorityLabels[p] ?? p,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }
}