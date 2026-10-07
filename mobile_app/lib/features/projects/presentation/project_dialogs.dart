import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/async_states.dart';
import '../../dashboard/data/dashboard_providers.dart';
import 'project_providers.dart';

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
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
    builder: (_) => const _CreateProjectDialog(),
  );
  if (result == null || result[0].length < 2) return;
  try {
    await ref.read(projectsRepositoryProvider).create(result[0], result[1]);
    ref.invalidate(projectsProvider);
    ref.invalidate(dashboardProvider);
    if (context.mounted) showSnack(context, 'Đã tạo dự án');
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e));
  }
}
