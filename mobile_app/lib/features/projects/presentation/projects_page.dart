import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_states.dart';
import '../../tasks/presentation/kanban_page.dart';
import 'project_dialogs.dart';
import 'project_providers.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateProjectDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Dự án mới'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(projectsProvider.future),
        child: projects.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(projectsProvider)),
          data: (items) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                Text(
                  'Dự án',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Chưa có dự án nào. Hãy tạo dự án đầu tiên!')),
                  ),
                for (final p in items)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: p.colorValue,
                        child: const Icon(Icons.work_outline, color: Colors.white),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        p.description.isEmpty
                            ? '${p.members.length} thành viên'
                            : '${p.description}\n${p.members.length} thành viên',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: p.description.isNotEmpty,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => KanbanPage(projectId: p.id, projectName: p.name),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
