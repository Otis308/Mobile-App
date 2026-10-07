import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/section_card.dart';
import '../../projects/presentation/project_dialogs.dart';
import '../../tasks/presentation/kanban_page.dart';
import '../../team/presentation/team_page.dart';
import '../data/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(dashboardProvider.future),
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(dashboardProvider)),
        data: (d) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng quan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Thông báo',
                  onPressed: () => _showNotifications(context, ref),
                  icon: Badge(
                    label: Text('${d.unreadNotifications}'),
                    isLabelVisible: d.unreadNotifications > 0,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _metric(context, 'Dự án', '${d.totalProjects}', Icons.folder_copy_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _metric(context, 'Hoàn tất 7 ngày', '${d.completedThisWeek}', Icons.task_alt_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _metric(context, 'Hiệu suất', '${d.completionRate}%', Icons.insights_rounded)),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Công việc hôm nay',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text('${d.todayTasks.length}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (d.todayTasks.isEmpty)
                    const Text('Không có công việc đến hạn hôm nay.')
                  else
                    for (final t in d.todayTasks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.radio_button_unchecked),
                        title: Text((t['title'] ?? '').toString()),
                        subtitle: Text(taskPriorityLabels[t['priority']] ?? (t['priority'] ?? 'medium').toString()),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dự án gần đây',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (d.projects.isEmpty) const Text('Chưa có dự án nào.'),
                  for (final p in d.projects)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.work_outline)),
                      title: Text((p['name'] ?? '').toString()),
                      subtitle: Text('${asMapList(p['members']).length} thành viên'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => KanbanPage(
                            projectId: p['_id'].toString(),
                            projectName: (p['name'] ?? '').toString(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => showCreateProjectDialog(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Tạo dự án mới'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TeamPage()),
              ),
              icon: const Icon(Icons.groups_rounded),
              label: const Text('Mở Team Workspace'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotifications(BuildContext context, WidgetRef ref) async {
    List<Map<String, dynamic>> items;
    try {
      items = await ref.read(notificationsProvider.future);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e));
      return;
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(18),
          children: [
            Text('Thông báo', style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (items.isEmpty) const Text('Chưa có thông báo.'),
            for (final n in items)
              ListTile(
                leading: Icon(n['isRead'] == true ? Icons.notifications_none : Icons.notifications_active_outlined),
                title: Text((n['message'] ?? '').toString()),
                subtitle: Text(_formatTime(n['createdAt'])),
                onTap: n['isRead'] == true
                    ? null
                    : () async {
                        try {
                          await ref.read(dashboardRepositoryProvider).markRead(n['_id'].toString());
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(dashboardProvider);
                        } catch (_) {}
                        if (sheet.mounted) Navigator.of(sheet).pop();
                      },
              ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(dynamic value) {
    final d = parseDate(value);
    return d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  Widget _metric(BuildContext c, String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(c).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
