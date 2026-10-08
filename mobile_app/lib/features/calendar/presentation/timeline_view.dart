import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../projects/domain/entities/project.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/presentation/due_utils.dart';
import '../../tasks/presentation/task_detail_page.dart';

class TimelineView extends StatefulWidget {
  final List<TaskModel> tasks;
  final List<ProjectModel> projects;

  const TimelineView({super.key, required this.tasks, required this.projects});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  static const double _dayW = 40;
  static const double _rowH = 34;
  static const double _tailW = 220; // chỗ trống bên phải để hiện tên công việc
  static const _wd = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  final _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  int _days(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  DateTime _start(TaskModel t) {
    final due = DateUtils.dateOnly(t.due!);
    final created = t.created;
    if (created == null) return due;
    final c = DateUtils.dateOnly(created);
    return c.isAfter(due) ? due : c;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks.where((t) => t.due != null).toList();
    if (tasks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Chưa có công việc nào có deadline.')),
        ],
      );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    var first = _addDays(today, -3);
    var last = _addDays(today, 14);
    for (final t in tasks) {
      final s = _start(t);
      final e = DateUtils.dateOnly(t.due!);
      if (s.isBefore(first)) first = s;
      if (e.isAfter(last)) last = e;
    }
    final limit = _addDays(today, -45);
    if (first.isBefore(limit)) first = limit;
    final totalDays = _days(first, last) + 1;
    final chartW = totalDays * _dayW + _tailW;

    final order = {
      for (var i = 0; i < widget.projects.length; i++) widget.projects[i].id: i,
    };
    final byId = {for (final p in widget.projects) p.id: p};
    tasks.sort((a, b) {
      final pa = order[a.projectId] ?? 999;
      final pb = order[b.projectId] ?? 999;
      if (pa != pb) return pa.compareTo(pb);
      return _start(a).compareTo(_start(b));
    });

    if (!_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final target = _days(first, today) * _dayW - 80;
        _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent).toDouble());
      });
    }

    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final p in widget.projects)
              if (tasks.any((t) => t.projectId == p.id))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: p.colorValue),
                    const SizedBox(width: 6),
                    Text(p.name, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Đỏ: quá hạn  •  Cam: hạn hôm nay  •  Xanh lá: hoàn tất',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartW,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < totalDays; i++) _tick(context, _addDays(first, i), today),
                      ],
                    ),
                    for (final t in tasks) _row(context, t, byId[t.projectId], first, totalDays, chartW),
                  ],
                ),
                Positioned(
                  left: _days(first, today) * _dayW + _dayW / 2 - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: scheme.primary.withAlpha(120)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tick(BuildContext context, DateTime d, DateTime today) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = DateUtils.isSameDay(d, today);
    final weekend = d.weekday >= 6;
    return Container(
      width: _dayW,
      height: 44,
      decoration: BoxDecoration(
        color: isToday
            ? scheme.primaryContainer
            : (weekend ? scheme.onSurface.withAlpha(12) : null),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_wd[d.weekday - 1], style: const TextStyle(fontSize: 10)),
          Text(
            d.day == 1 ? '1/${d.month}' : '${d.day}',
            style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, TaskModel t, ProjectModel? p, DateTime first, int totalDays, double chartW) {
    final s = _start(t);
    final e = DateUtils.dateOnly(t.due!);
    final startIdx = math.max(0, _days(first, s));
    final endIdx = math.min(totalDays - 1, _days(first, e));
    final width = math.max(1, endIdx - startIdx + 1) * _dayW;

    final state = dueStateOf(t);
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    if (state == DueState.overdue || state == DueState.today || state == DueState.done) {
      color = dueColor(context, state);
    } else {
      color = p?.colorValue ?? scheme.primary;
    }

    final label = p == null ? t.title : '${p.name} • ${t.title}';
    return SizedBox(
      height: _rowH,
      width: chartW,
      child: Stack(
        children: [
          Positioned(
            left: startIdx * _dayW + 2,
            top: 5,
            width: width - 4,
            height: _rowH - 10,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => TaskDetailPage(taskId: t.id)),
              ),
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Positioned(
            left: startIdx * _dayW + width + 4,
            top: 0,
            bottom: 0,
            width: 200,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}