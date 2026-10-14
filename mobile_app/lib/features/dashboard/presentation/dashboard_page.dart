import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/section_card.dart';
import '../../projects/presentation/project_dialogs.dart';
import '../../tasks/presentation/kanban_page.dart';
import '../../tasks/presentation/task_detail_page.dart';
import '../../team/presentation/team_page.dart';
import '../data/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng quan công việc',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, dd/MM/yyyy').format(DateTime.now()),
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                IconButton.outlined(
                  tooltip: 'Thông báo',
                  onPressed: () => _showNotifications(context, ref),
                  icon: Badge(
                    label: Text('${d.unreadNotifications}'),
                    isLabelVisible: d.unreadNotifications > 0,
                    child: const Icon(Icons.notifications_none_rounded, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    context,
                    'Dự án',
                    '${d.totalProjects}',
                    Icons.folder_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    context,
                    'Xong 7 ngày',
                    '${d.completedThisWeek}',
                    Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    context,
                    'Hoàn tất',
                    '${d.completionRate}%',
                    Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showCreateProjectDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Dự án mới'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const TeamPage()),
                    ),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Thành viên'),
                  ),
                ),
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
                        'Cần xử lý hôm nay',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${d.todayTasks.length}',
                          style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (d.todayTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Bạn không có công việc nào đến hạn hôm nay.',
                        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    for (final t in d.todayTasks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        leading: Icon(
                          Icons.circle_outlined,
                          size: 18,
                          color: t['priority'] == 'urgent' ? scheme.error : scheme.primary,
                        ),
                        title: Text(
                          (t['title'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Ưu tiên: ${taskPriorityLabels[t['priority']] ?? (t['priority'] ?? 'medium')}',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                        onTap: () {
                          final taskId = (t['_id'] ?? '').toString();
                          if (taskId.isEmpty) return;
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TaskDetailPage(taskId: taskId),
                                ),
                              )
                              .then((_) => ref.invalidate(dashboardProvider));
                        },
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dự án gần đây',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (d.projects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Chưa có dự án nào.',
                        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  for (final p in d.projects)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _parseColor((p['color'] ?? '3E6FF2').toString()),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        (p['name'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${asMapList(p['members']).length} thành viên',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
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
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.tryParse('FF$cleaned', radix: 16) ?? 0xFF2563EB);
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
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Thông báo',
                    style: Theme.of(sheet)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (items.any((n) => n['isRead'] != true))
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref.read(dashboardRepositoryProvider).markAllRead();
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(dashboardProvider);
                        } catch (_) {}
                        if (sheet.mounted) Navigator.of(sheet).pop();
                      },
                      child: const Text('Đánh dấu đã đọc'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Không có thông báo nào.')),
                )
              else
                for (final n in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      n['type'] == 'COMMENT'
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.notifications_none_rounded,
                      size: 20,
                      color: n['isRead'] == true
                          ? Theme.of(sheet).colorScheme.outline
                          : Theme.of(sheet).colorScheme.primary,
                    ),
                    title: Text(
                      (n['message'] ?? '').toString(),
                      style: TextStyle(
                        fontWeight: n['isRead'] == true ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(_formatTime(n['createdAt'])),
                    onTap: () async {
                      final link = (n['link'] ?? '').toString();
                      if (n['isRead'] != true) {
                        try {
                          await ref
                              .read(dashboardRepositoryProvider)
                              .markRead(n['_id'].toString());
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(dashboardProvider);
                        } catch (_) {}
                      }
                      if (sheet.mounted) Navigator.of(sheet).pop();
                      if (link.startsWith('/tasks/') && context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                TaskDetailPage(taskId: link.substring('/tasks/'.length)),
                          ),
                        );
                      }
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(dynamic value) {
    final d = parseDate(value);
    return d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  Widget _metric(BuildContext c, String label, String value, IconData icon) {
    final scheme = Theme.of(c).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(c).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}