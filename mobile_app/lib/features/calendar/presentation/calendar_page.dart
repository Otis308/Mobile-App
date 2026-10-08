import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_states.dart';
import '../../projects/domain/entities/project.dart';
import '../../projects/presentation/project_providers.dart';
import '../../tasks/presentation/task_providers.dart';
import 'deadline_list.dart';
import 'month_calendar.dart';
import 'timeline_view.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? const <ProjectModel>[];
    final names = {for (final p in projects) p.id: p.name};

    Future<void> refresh() => ref.refresh(allTasksProvider.future);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Lịch'), Tab(text: 'Timeline'), Tab(text: 'Deadline')],
          ),
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(allTasksProvider)),
              data: (tasks) => TabBarView(
                // Tắt vuốt ngang giữa các tab để không tranh với cuộn ngang của Timeline.
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  RefreshIndicator(
                    onRefresh: refresh,
                    child: MonthCalendar(tasks: tasks, projectNames: names),
                  ),
                  RefreshIndicator(
                    onRefresh: refresh,
                    child: TimelineView(tasks: tasks, projects: projects),
                  ),
                  RefreshIndicator(
                    onRefresh: refresh,
                    child: DeadlineList(tasks: tasks, projectNames: names),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}