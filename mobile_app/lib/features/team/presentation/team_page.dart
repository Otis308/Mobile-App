import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../../projects/domain/entities/project.dart';
import '../../projects/presentation/project_providers.dart';
import 'team_providers.dart';

const _roleLabels = {'owner': 'Chủ dự án', 'manager': 'Quản lý', 'member': 'Thành viên'};

class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key});

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  String? _projectId;

  Future<void> _openInvite(String projectId) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(projectId: projectId),
    );
    if (added == true) ref.invalidate(projectsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Team Workspace')),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(projectsProvider)),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Bạn chưa có dự án nào.'));
          final current = list.firstWhere(
            (p) => p.id == _projectId,
            orElse: () => list.first,
          );
          return _body(context, list, current);
        },
      ),
      floatingActionButton: (projects.valueOrNull ?? const <ProjectModel>[]).isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final list = projects.valueOrNull ?? const <ProjectModel>[];
                if (list.isEmpty) return;
                final id = list.any((p) => p.id == _projectId) ? _projectId! : list.first.id;
                _openInvite(id);
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Mời thành viên'),
            ),
    );
  }

  Widget _body(BuildContext context, List<ProjectModel> list, ProjectModel current) {
    final members = ref.watch(projectMembersProvider(current.id));
    final roles = current.roleByUser;

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
        Text('Thành viên', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        members.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: Text(errorMessage(e))),
          data: (items) => Column(
            children: [
              for (final u in items)
                ListTile(
                  leading: AppAvatar(name: (u['fullName'] ?? '?').toString()),
                  title: Text((u['fullName'] ?? '').toString()),
                  subtitle: Text('@${u['username'] ?? ''}'),
                  trailing: Text(_roleLabels[roles[u['_id'].toString()]] ?? 'Thành viên'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  final String projectId;

  const _InviteSheet({required this.projectId});

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
      final found = await ref.read(teamRepositoryProvider).search(q);
      if (!mounted) return;
      setState(() {
        _results = found;
        _message = found.isEmpty ? 'Không tìm thấy người dùng phù hợp.' : null;
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
