import '../../../../core/utils/json_utils.dart';

class DashboardModel {
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> todayTasks;
  final int totalProjects;
  final int unreadNotifications;
  final int completedThisWeek;
  final int assignedTotal;
  final int completionRate;

  const DashboardModel({
    required this.projects,
    required this.todayTasks,
    required this.totalProjects,
    required this.unreadNotifications,
    required this.completedThisWeek,
    required this.assignedTotal,
    required this.completionRate,
  });

  static int _int(dynamic v) => v is num ? v.toInt() : 0;

  factory DashboardModel.fromJson(Map<String, dynamic> j) {
    final perf = asMap(j['performance']);
    return DashboardModel(
      projects: asMapList(j['projects']),
      todayTasks: asMapList(j['todayTasks']),
      totalProjects: _int(j['totalProjects']),
      unreadNotifications: _int(j['unreadNotifications']),
      completedThisWeek: _int(perf['completedThisWeek']),
      assignedTotal: _int(perf['assignedTotal']),
      completionRate: _int(perf['completionRate']),
    );
  }
}
