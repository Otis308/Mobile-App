import 'package:flutter/material.dart';

import '../domain/entities/task.dart';

enum DueState { done, overdue, today, soon, later, none }

int daysUntilDue(DateTime due) {
  final now = DateTime.now();
  final a = DateTime.utc(now.year, now.month, now.day);
  final b = DateTime.utc(due.year, due.month, due.day);
  return b.difference(a).inDays;
}

DueState dueStateOf(TaskModel t) {
  if (t.status == 'done') return DueState.done;
  final due = t.due;
  if (due == null) return DueState.none;
  final d = daysUntilDue(due);
  if (d < 0) return DueState.overdue;
  if (d == 0) return DueState.today;
  if (d <= 3) return DueState.soon;
  return DueState.later;
}

Color dueColor(BuildContext context, DueState s) {
  final scheme = Theme.of(context).colorScheme;
  switch (s) {
    case DueState.overdue:
      return scheme.error;
    case DueState.today:
      return Colors.deepOrange;
    case DueState.soon:
      return Colors.amber.shade800;
    case DueState.done:
      return Colors.green.shade600;
    case DueState.later:
    case DueState.none:
      return scheme.onSurfaceVariant;
  }
}

String dueLabel(TaskModel t) {
  final due = t.due;
  switch (dueStateOf(t)) {
    case DueState.done:
      return 'Đã hoàn tất';
    case DueState.none:
      return 'Chưa có deadline';
    case DueState.overdue:
      return 'Quá hạn ${-daysUntilDue(due!)} ngày';
    case DueState.today:
      return 'Hạn hôm nay';
    case DueState.soon:
    case DueState.later:
      return 'Còn ${daysUntilDue(due!)} ngày';
  }
}