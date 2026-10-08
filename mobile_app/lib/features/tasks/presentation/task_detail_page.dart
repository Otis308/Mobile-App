import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../../projects/presentation/project_providers.dart';
import '../domain/entities/task.dart';
import 'task_providers.dart';
import 'edit_task_dialog.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _comment = TextEditingController();
  late final SocketService _socket;
  StreamSubscription<RealtimeEvent>? _sub;
  bool _sending = false;
  String? _joined;
  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _sub = _socket.events.listen((event) {
      if (!mounted) return;
      if (event.name == 'comment.created') {
        final data = event.data;
        if (data is Map && data['taskId']?.toString() == widget.taskId) {
          ref.invalidate(commentsProvider(widget.taskId));
        }
      } else if (event.name == 'task.updated' || event.name == 'task.moved') {
        ref.invalidate(taskProvider(widget.taskId));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _comment.dispose();
    super.dispose();
    final id = _joined;
    if (id != null) _socket.leaveProject(id);
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(commentsRepositoryProvider).create(widget.taskId, text);
      _comment.clear();
      ref.invalidate(commentsProvider(widget.taskId));
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickDate(TaskModel t) async {
    final now = DateTime.now();
    final current = t.due ?? now;
    final first = current.isBefore(now) ? current : now;
    final date = await showDatePicker(
      context: context,
      firstDate: first.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      initialDate: current,
    );
    if (date == null || !mounted) return;
    try {
      // Hạn chót đặt lúc 17:00 giờ địa phương.
      final due = DateTime(date.year, date.month, date.day, 17);
      await ref.read(tasksRepositoryProvider).update(t.id, {'dueDate': due.toUtc().toIso8601String()});
      ref.invalidate(taskProvider(widget.taskId));
      if (mounted) showSnack(context, 'Đã cập nhật hạn ${DateFormat('dd/MM/yyyy').format(due)}');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  Future<void> _clearDate(TaskModel t) async {
    try {
      await ref.read(tasksRepositoryProvider).update(t.id, {'dueDate': null});
      ref.invalidate(taskProvider(widget.taskId));
      if (mounted) showSnack(context, 'Đã xóa hạn chót');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  Future<void> _changeStatus(TaskModel t, String status) async {
    if (status == t.status) return;
    try {
      // order lớn để thẻ xuống cuối cột đích.
      await ref.read(tasksRepositoryProvider).move(t.id, status, 9999);
      ref.invalidate(taskProvider(widget.taskId));
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  Future<void> _edit(TaskModel t) async {
    List<Map<String, dynamic>> members = const [];
    try {
      members = await ref.read(projectMembersProvider(t.projectId).future);
    } catch (_) {}
    if (!mounted) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditTaskDialog(task: t, members: members),
    );
    if (data == null) return;
    try {
      await ref.read(tasksRepositoryProvider).update(t.id, data);
      ref.invalidate(taskProvider(widget.taskId));
      if (mounted) showSnack(context, 'Đã cập nhật công việc');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  Future<void> _delete(TaskModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc?'),
        content: Text('"${t.title}" sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(tasksRepositoryProvider).delete(t.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(taskProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          if (task.hasValue)
            IconButton(
              tooltip: 'Sửa',
              onPressed: () => _edit(task.requireValue),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (task.hasValue)
            IconButton(
              tooltip: 'Xóa',
              onPressed: () => _delete(task.requireValue),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: task.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(taskProvider(widget.taskId))),
        data: (t) => _content(context, t),
      ),
    );
  }

  Widget _content(BuildContext context, TaskModel t) {
    final textTheme = Theme.of(context).textTheme;
    final due = t.due;
    final members = ref.watch(projectMembersProvider(t.projectId)).valueOrNull ??
      const <Map<String, dynamic>>[];
    final assignee =
      members.where((m) => m['_id'].toString() == t.assigneeId).firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(t.title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(label: Text('Ưu tiên: ${taskPriorityLabels[t.priority] ?? t.priority}')),
            for (final l in t.labels) Chip(label: Text('#$l')),
          ],
        ),
        const SizedBox(height: 12),
        LabeledDropdown<String>(
          label: 'Trạng thái',
          value: t.status,
          items: [
            for (final e in taskStatusLabels.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) _changeStatus(t, v);
          },
        ),
        const SizedBox(height: 18),
        Text(t.description.isEmpty ? 'Chưa có mô tả.' : t.description),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: const Text('Người thực hiện'),
          subtitle: Text(assignee == null ? 'Chưa giao' : (assignee['fullName'] ?? '').toString()),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: const Text('Hạn chót'),
          subtitle: Text(due == null ? 'Chưa đặt (chạm để chọn)' : DateFormat('dd/MM/yyyy HH:mm').format(due)),
          trailing: due == null
              ? null
              : IconButton(
                  tooltip: 'Xóa hạn',
                  icon: const Icon(Icons.close),
                  onPressed: () => _clearDate(t),
                ),
          onTap: () => _pickDate(t),
        ),
        const Divider(height: 28),
        Text('Bình luận', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _comments(context, t),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _comment,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Viết bình luận...'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _comments(BuildContext context, TaskModel t) {
    final comments = ref.watch(commentsProvider(widget.taskId));
    final members = ref.watch(projectMembersProvider(t.projectId));
    final names = <String, String>{
      for (final m in members.valueOrNull ?? const <Map<String, dynamic>>[])
        m['_id'].toString(): (m['fullName'] ?? '').toString(),
    };

    return comments.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Lỗi bình luận: ${errorMessage(e)}'),
      data: (items) {
        if (items.isEmpty) return const Text('Chưa có bình luận.');
        return Column(
          children: [
            for (final x in items)
              Align(
                alignment: Alignment.centerLeft,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          names[x.authorId] ?? 'Thành viên',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(x.content),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM HH:mm').format(x.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
