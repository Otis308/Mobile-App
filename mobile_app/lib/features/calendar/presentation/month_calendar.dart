import 'package:flutter/material.dart';

import '../../tasks/domain/entities/task.dart';
import '../../tasks/presentation/due_utils.dart';
import 'deadline_list.dart';

class MonthCalendar extends StatefulWidget {
  final List<TaskModel> tasks;
  final Map<String, String> projectNames;

  const MonthCalendar({super.key, required this.tasks, required this.projectNames});

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateUtils.dateOnly(DateTime.now());

  void _go(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _today() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = DateUtils.dateOnly(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<TaskModel>>{};
    for (final t in widget.tasks) {
      final due = t.due;
      if (due == null) continue;
      byDay.putIfAbsent(DateUtils.dateOnly(due), () => <TaskModel>[]).add(t);
    }

    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final lead = DateTime(_month.year, _month.month, 1).weekday - 1;
    final weeks = ((lead + days) / 7).ceil();
    DateTime? dayAt(int n) => (n < 1 || n > days) ? null : DateTime(_month.year, _month.month, n);

    final selectedTasks = [...(byDay[_selected] ?? const <TaskModel>[])]
      ..sort((a, b) => a.due!.compareTo(b.due!));
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                'Tháng ${_month.month}/${_month.year}',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(onPressed: () => _go(1), icon: const Icon(Icons.chevron_right)),
            TextButton(onPressed: _today, child: const Text('Hôm nay')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(child: Center(child: Text(w, style: textTheme.labelMedium))),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++) _cell(context, dayAt(w * 7 + d - lead + 1), byDay),
            ],
          ),
        const SizedBox(height: 16),
        Text(
          'Công việc ngày ${_selected.day}/${_selected.month}/${_selected.year}',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (selectedTasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Không có công việc đến hạn trong ngày này.'),
          ),
        for (final t in selectedTasks)
          TaskDueTile(task: t, projectName: widget.projectNames[t.projectId] ?? ''),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime? day, Map<DateTime, List<TaskModel>> byDay) {
    if (day == null) return const Expanded(child: SizedBox(height: 52));
    final items = byDay[day] ?? const <TaskModel>[];
    final selected = DateUtils.isSameDay(day, _selected);
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selected = day),
        child: Container(
          height: 52,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : null,
            border: isToday ? Border.all(color: scheme.primary) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final t in items.take(3))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: _dotColor(context, t),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _dotColor(BuildContext context, TaskModel t) {
    final s = dueStateOf(t);
    return s == DueState.later ? Theme.of(context).colorScheme.primary : dueColor(context, s);
  }
}