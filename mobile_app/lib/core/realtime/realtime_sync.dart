import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/data/dashboard_providers.dart';
import '../../features/projects/presentation/project_providers.dart';
import '../../features/tasks/presentation/task_providers.dart';
import '../network/socket_service.dart';
import '../providers.dart';
import '../utils/json_utils.dart';
import '../widgets/async_states.dart';
import 'presence_provider.dart';

/// Lắng nghe sự kiện realtime toàn app và làm mới dữ liệu liên quan.
class RealtimeSync extends ConsumerStatefulWidget {
  final Widget child;

  const RealtimeSync({super.key, required this.child});

  @override
  ConsumerState<RealtimeSync> createState() => _RealtimeSyncState();
}

class _RealtimeSyncState extends ConsumerState<RealtimeSync> {
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _debounce;
  bool _tasksDirty = false;
  bool _projectsDirty = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(socketServiceProvider).events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _mark({bool tasks = false, bool projects = false}) {
    _tasksDirty = _tasksDirty || tasks;
    _projectsDirty = _projectsDirty || projects;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _flush);
  }

  void _flush() {
    if (!mounted) return;
    if (_projectsDirty) {
      ref.invalidate(projectsProvider);
      ref.invalidate(projectMembersProvider);
    }
    if (_tasksDirty || _projectsDirty) {
      ref.invalidate(allTasksProvider);
      ref.invalidate(tasksProvider);
      ref.invalidate(dashboardProvider);
    }
    _tasksDirty = false;
    _projectsDirty = false;
  }

  void _onEvent(RealtimeEvent e) {
    switch (e.name) {
      case 'presence.update':
        final m = asMap(e.data);
        final raw = m['onlineUserIds'];
        final ids = raw is List ? raw.map((x) => x.toString()).toSet() : <String>{};
        ref.read(presenceProvider.notifier).setOnline((m['projectId'] ?? '').toString(), ids);
        break;
      case 'notification.created':
        ref.invalidate(notificationsProvider);
        ref.invalidate(dashboardProvider);
        final msg = (asMap(e.data)['message'] ?? '').toString();
        if (msg.isNotEmpty && mounted) showSnack(context, msg);
        break;
      case 'task.created':
      case 'task.updated':
      case 'task.moved':
      case 'task.deleted':
        _mark(tasks: true);
        break;
      case 'project.updated':
      case 'project.memberAdded':
      case 'project.memberRemoved':
      case 'project.memberUpdated':
      case 'project.deleted':
        _mark(projects: true);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}