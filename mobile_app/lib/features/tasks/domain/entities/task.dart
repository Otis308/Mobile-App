class TaskModel {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String? assigneeId;
  final String? dueDate;
  final List<String> labels;
  final int order;
  final String? createdAt;  
  final DateTime? due;

  const TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.assigneeId,
    this.dueDate,
    this.labels = const [],
    this.order = 0,
    this.createdAt,  
    this.due,
  });

  factory TaskModel.fromJson(Map<String, dynamic> j) => TaskModel(
        id: (j['_id'] ?? '').toString(),
        projectId: (j['projectId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        priority: (j['priority'] ?? 'medium').toString(),
        status: (j['status'] ?? 'todo').toString(),
        assigneeId: j['assigneeId']?.toString(),
        dueDate: j['dueDate']?.toString(),
        labels: j['labels'] is List
            ? (j['labels'] as List).map((e) => e.toString()).toList()
            : const [],
        order: j['order'] is num ? (j['order'] as num).toInt() : 0,
        createdAt: j['createdAt']?.toString(),
      );
  DateTime? get created => createdAt == null ? null : DateTime.tryParse(createdAt!)?.toLocal();
}
