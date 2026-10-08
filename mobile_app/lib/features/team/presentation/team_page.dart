import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../../projects/domain/entities/project.dart';
import '../../projects/presentation/project_providers.dart';
import 'team_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../tasks/domain/entities/task.dart';
import '../../tasks/presentation/task_providers.dart';
import '../../../core/realtime/presence_provider.dart';

const _roleLabels = {'owner': 'Chủ dự án', 'manager': 'Quản lý', 'member': 'Thành viên'};
int _roleRank(String? r) => r == 'owner' ? 0 : (r == 'manager' ? 1 : 2);

class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key});
  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  String? _projectId;

  Future<void> _openInvite(ProjectModel p) async {
    final existing = {for (final m in p.members) m['userId'].toString()};
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(projectId: p.id, existingIds: existing),
    );
    if (added == true) ref.invalidate(projectsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final me = ref.watch(authControllerProvider).user?.id;
    final list = projects.valueOrNull ?? const <ProjectModel>[];
    final current = list.isEmpty
        ? null
        : list.firstWhere((p) => p.id == _projectId, orElse: () => list.first);
    final canInvite =
        current != null && const {'owner', 'manager'}.contains(current.roleByUser[me]);

    return Scaffold(
      appBar: AppBar(title: const Text('Team Workspace')),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(projectsProvider)),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('Bạn chưa có dự án nào.'));
          final cur = items.firstWhere((p) => p.id == _projectId, orElse: () => items.first);
          return _body(context, items, cur);
        },
      ),
      floatingActionButton: canInvite
          ? FloatingActionButton.extended(
              onPressed: () => _openInvite(current!),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Mời thành viên'),
            )
          : null,
    );
  }

  Widget _body(BuildContext context, List<ProjectModel> list, ProjectModel current) {
    final members = ref.watch(projectMembersProvider(current.id));
    final tasks = ref.watch(tasksProvider(current.id)).valueOrNull ?? const <TaskModel>[];
    final me = ref.watch(authControllerProvider).user?.id;
    final roles = current.roleByUser;
    final myRole = roles[me] ?? 'member';
    final onlineIds = ref.watch(presenceProvider)[current.id] ?? const <String>{};

    int openTasks(String userId) =>
        tasks.where((t) => t.assigneeId == userId && t.status != 'done').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
      children: [
        LabeledDropdown<String>(
          label: 'Dự án',
          value: current.id,
          items: [for (final p in list) DropdownMenuItem(value: p.id, child: Text(p.name))],
          onChanged: (v) => setState(() => _projectId = v),
        ),
        const SizedBox(height: 20),
        Text(
          'Thành viên (${current.members.length}) • ${onlineIds.length} online',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        members.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: Text(errorMessage(e))),
          data: (items) {
            final sorted = [...items]..sort((a, b) =>
                _roleRank(roles[a['_id'].toString()]).compareTo(_roleRank(roles[b['_id'].toString()])));
            return Column(
              children: [
                for (final u in sorted)
                  _memberTile(context, current, u, roles, myRole, me, openTasks(u['_id'].toString()),
                    online: onlineIds.contains(u['_id'].toString())),
              ],
            );
          },
        ),
        if (myRole != 'owner' && me != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton.icon(
              onPressed: () => _remove(current, me, 'bạn', self: true),
              icon: const Icon(Icons.logout),
              label: const Text('Rời khỏi dự án'),
            ),
          ),
      ],
    );
  }

  Widget _memberTile(
    BuildContext context,
    ProjectModel project,
    Map<String, dynamic> u,
    Map<String, String> roles,
    String myRole,
    String? me,
    int openTasks, {
    bool online = false,
  }) {
    final id = u['_id'].toString();
    final role = roles[id] ?? 'member';
    final isMe = id == me;
    final name = (u['fullName'] ?? '').toString();
    final canRemove = !isMe &&
        role != 'owner' &&
        (myRole == 'owner' || (myRole == 'manager' && role == 'member'));
    final canChangeRole = myRole == 'owner' && role != 'owner';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        children: [
          AppAvatar(name: name.isEmpty ? '?' : name),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(isMe ? '$name (Bạn)' : name),
      subtitle: Text('@${u['username'] ?? ''} • $openTasks việc đang làm'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_roleLabels[role] ?? 'Thành viên', style: Theme.of(context).textTheme.labelMedium),
          if (canRemove || canChangeRole)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'role') _changeRole(project, id, role == 'manager' ? 'member' : 'manager');
                if (v == 'remove') _remove(project, id, name);
              },
              itemBuilder: (_) => [
                if (canChangeRole)
                  PopupMenuItem(
                    value: 'role',
                    child: Text(role == 'manager' ? 'Hạ xuống Thành viên' : 'Nâng lên Quản lý'),
                  ),
                if (canRemove) const PopupMenuItem(value: 'remove', child: Text('Xóa khỏi nhóm')),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _changeRole(ProjectModel p, String userId, String role) async {
    try {
      await ref.read(projectsRepositoryProvider).updateMemberRole(p.id, userId, role);
      ref.invalidate(projectsProvider);
      if (mounted) showSnack(context, 'Đã cập nhật quyền');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  Future<void> _remove(ProjectModel p, String userId, String name, {bool self = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(self ? 'Rời khỏi dự án?' : 'Xóa thành viên?'),
        content: Text(self
            ? 'Bạn sẽ không còn truy cập "${p.name}". Việc đang giao cho bạn sẽ chuyển về "Chưa giao".'
            : 'Xóa $name khỏi "${p.name}"? Việc đang giao cho họ sẽ chuyển về "Chưa giao".'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(self ? 'Rời nhóm' : 'Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectsRepositoryProvider).removeMember(p.id, userId);
      ref.invalidate(projectsProvider);
      ref.invalidate(projectMembersProvider(p.id));
      ref.invalidate(tasksProvider(p.id));
      if (!mounted) return;
      if (self) setState(() => _projectId = null);
      showSnack(context, self ? 'Bạn đã rời dự án' : 'Đã xóa thành viên');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  final String projectId;
  final Set<String> existingIds;

  const _InviteSheet({required this.projectId, required this.existingIds});

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String? _message;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() => _message = 'Nhập ít nhất 2 ký tự để tìm người dùng.');
      return;
    }
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final found = (await ref.read(teamRepositoryProvider).search(q))
          .where((u) => !widget.existingIds.contains(u['_id'].toString()))
          .toList();
          
      if (!mounted) return;
      setState(() {
        _results = found;
        _message = found.isEmpty ? 'Không tìm thấy người dùng phù hợp (hoặc đã ở trong dự án).' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _message = errorMessage(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _invite(Map<String, dynamic> user) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Chọn quyền thành viên')),
            ListTile(title: const Text('Thành viên'), onTap: () => Navigator.of(c).pop('member')),
            ListTile(title: const Text('Quản lý'), onTap: () => Navigator.of(c).pop('manager')),
          ],
        ),
      ),
    );
    if (role == null || !mounted) return;
    try {
      await ref.read(projectsRepositoryProvider).addMember(widget.projectId, user['_id'].toString(), role);
      ref.invalidate(projectMembersProvider(widget.projectId));
      if (!mounted) return;
      showSnack(context, 'Đã thêm ${user['fullName']} vào nhóm');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(hintText: 'Email hoặc username'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _searching ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_searching) const LinearProgressIndicator(),
            if (_message != null) Text(_message!),
            if (_results.isEmpty && _message == null && !_searching)
              const Text('Nhập ít nhất 2 ký tự để tìm người dùng.'),
            for (final u in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppAvatar(name: (u['fullName'] ?? '?').toString()),
                title: Text((u['fullName'] ?? '').toString()),
                subtitle: Text('${u['username']} • ${u['email']}'),
                trailing: IconButton(
                  onPressed: () => _invite(u),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}