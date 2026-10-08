import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/async_states.dart';
import '../../dashboard/data/dashboard_providers.dart';
import 'project_providers.dart';
import '../domain/entities/project.dart';

const projectColors = ['3E6FF2', 'E5484D', 'F5A524', '17C964', '7828C8', '06B6D4'];

class _ProjectDialog extends StatefulWidget {
  final String title, confirm, name, desc, color;
  const _ProjectDialog({
    this.title = 'Tạo dự án',
    this.confirm = 'Tạo',
    this.name = '',
    this.desc = '',
    this.color = '3E6FF2',
  });

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _desc = TextEditingController(text: widget.desc);
  late String _color = widget.color;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên dự án (2-100 ký tự)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                for (final c in projectColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(int.parse('FF$c', radix: 16)),
                      child: _color == c
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .pop(<String>[_name.text.trim(), _desc.text.trim(), _color]),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

class _CreateProjectDialogState extends State<_ProjectDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo dự án'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên dự án (2-100 ký tự)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(<String>[_name.text.trim(), _desc.text.trim()]),
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

Future<void> showCreateProjectDialog(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<List<String>>(
    context: context,
    builder: (_) => const _ProjectDialog(),
  );
  if (result == null || result[0].length < 2) return;
  try {
    await ref.read(projectsRepositoryProvider).create(result[0], result[1], color: result[2]);
    ref.invalidate(projectsProvider);
    ref.invalidate(dashboardProvider);
    if (context.mounted) showSnack(context, 'Đã tạo dự án');
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e));
  }
}

Future<void> showEditProjectDialog(BuildContext context, WidgetRef ref, ProjectModel p) async {
  final r = await showDialog<List<String>>(
    context: context,
    builder: (_) => _ProjectDialog(
      title: 'Sửa dự án', confirm: 'Lưu', name: p.name, desc: p.description, color: p.color,
    ),
  );
  if (r == null || r[0].length < 2) return;
  try {
    await ref.read(projectsRepositoryProvider).update(p.id, name: r[0], description: r[1], color: r[2]);
    ref.invalidate(projectsProvider);
    ref.invalidate(dashboardProvider);
    if (context.mounted) showSnack(context, 'Đã cập nhật dự án');
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e));
  }
}

Future<void> confirmDeleteProject(BuildContext context, WidgetRef ref, ProjectModel p) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xóa dự án?'),
      content: Text('"${p.name}" cùng toàn bộ công việc và bình luận sẽ bị xóa vĩnh viễn.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Xóa')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(projectsRepositoryProvider).delete(p.id);
    ref.invalidate(projectsProvider);
    ref.invalidate(dashboardProvider);
    if (context.mounted) showSnack(context, 'Đã xóa dự án');
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e));
  }
}