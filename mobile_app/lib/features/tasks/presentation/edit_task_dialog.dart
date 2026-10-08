import 'package:flutter/material.dart';

import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../domain/entities/task.dart';

class EditTaskDialog extends StatefulWidget {
  final TaskModel task;
  final List<Map<String, dynamic>> members;

  const EditTaskDialog({super.key, required this.task, required this.members});

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _desc = TextEditingController(text: widget.task.description);
  late final _labels = TextEditingController(text: widget.task.labels.join(', '));
  late String _priority = widget.task.priority;
  // '' = chưa giao (tránh dùng null làm value của Dropdown)
  late String _assignee =
      widget.members.any((m) => m['_id'].toString() == widget.task.assigneeId)
          ? widget.task.assigneeId!
          : '';

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _labels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _title.text.trim().length >= 2;
    return AlertDialog(
      title: const Text('Sửa công việc'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Tiêu đề (2-180 ký tự)',
                errorText: valid ? null : 'Tối thiểu 2 ký tự',
              ),
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
            const SizedBox(height: 10),
            LabeledDropdown<String>(
              label: 'Người thực hiện',
              value: _assignee,
              items: [
                const DropdownMenuItem(value: '', child: Text('Chưa giao')),
                for (final m in widget.members)
                  DropdownMenuItem(
                    value: m['_id'].toString(),
                    child: Text((m['fullName'] ?? '').toString()),
                  ),
              ],
              onChanged: (v) => setState(() => _assignee = v ?? ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _labels,
              decoration: const InputDecoration(
                labelText: 'Nhãn (cách nhau bởi dấu phẩy)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
        FilledButton(
          onPressed: valid
              ? () => Navigator.of(context).pop(<String, dynamic>{
                    'title': _title.text.trim(),
                    'description': _desc.text.trim(),
                    'priority': _priority,
                    'assigneeId': _assignee.isEmpty ? null : _assignee,
                    'labels': _labels.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toSet()
                        .toList(),
                  })
              : null,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}