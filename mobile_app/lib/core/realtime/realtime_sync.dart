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

class RealtimeSync extends ConsumerStatefulWidget {
  final Widget child;

  const RealtimeSync({super.key, required this.child});

  @override
  ConsumerState<RealtimeSync> createState() => _RealtimeSyncState();
}

class _RealtimeSyncState extends ConsumerState<RealtimeSync> {
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _debounce;
  bool _allTasksDirty = false;
  bool _projectsDirty = false;
  final Set<String> _dirtyProjectIds = {};

  @override
  void initState() {
    super.initState();
    final socket = ref.read(socketServiceProvider);
    _sub = socket.events.listen(_onEvent);
    // Yêu cầu server gửi lại danh sách online mới nhất ngay khi giao diện chính được dựng xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      socket.syncPresence();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _mark({String? projectId, bool tasks = false, bool projects = false}) {
    if (projectId != null && projectId.isNotEmpty) {
      _dirtyProjectIds.add(projectId);
    }
    _allTasksDirty = _allTasksDirty || tasks;
    _projectsDirty = _projectsDirty || projects;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _flush);
  }

  void _flush() {
    if (!mounted) return;
    if (_projectsDirty) {
      ref.invalidate(projectsProvider);
      for (final pid in _dirtyProjectIds) {
        ref.invalidate(projectMembersProvider(pid));
      }
    }
    if (_allTasksDirty || _projectsDirty) {
      if (_dirtyProjectIds.isNotEmpty) {
        for (final pid in _dirtyProjectIds) {
          ref.invalidate(tasksProvider(pid));
        }
      } else {
        ref.invalidate(tasksProvider);
      }
      ref.invalidate(allTasksProvider);
      ref.invalidate(dashboardProvider);
    }
    _dirtyProjectIds.clear();
    _allTasksDirty = false;
    _projectsDirty = false;
  }

  void _onEvent(RealtimeEvent e) {
    final payload = asMap(e.data);
    final pid = (payload['projectId'] ?? payload['_id'] ?? '').toString();

    switch (e.name) {
      case 'presence.update':
        final raw = payload['onlineUserIds'];
        final ids = raw is List ? raw.map((x) => x.toString()).toSet() : <String>{};
        ref.read(presenceProvider.notifier).setOnline((payload['projectId'] ?? '').toString(), ids);
        break;
      case 'notification.created':
        ref.invalidate(notificationsProvider);
        ref.invalidate(dashboardProvider);
        final msg = (payload['message'] ?? '').toString();
        if (msg.isNotEmpty && mounted) showSnack(context, msg);
        break;
      case 'task.created':
      case 'task.updated':
      case 'task.moved':
      case 'task.deleted':
        _mark(projectId: pid, tasks: true);
        break;
      case 'project.updated':
      case 'project.memberAdded':
      case 'project.memberRemoved':
      case 'project.memberUpdated':
      case 'project.deleted':
        _mark(projectId: pid, projects: true);
        ref.read(socketServiceProvider).syncPresence(pid);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}