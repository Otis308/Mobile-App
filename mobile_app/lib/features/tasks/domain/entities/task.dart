import '../../../../core/utils/json_utils.dart';

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
  final String? updatedAt;
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
    this.updatedAt,
    this.due,
  });

  factory TaskModel.fromJson(Map<String, dynamic> j) {
    final rawDue = j['dueDate']?.toString();
    return TaskModel(
      id: (j['_id'] ?? '').toString(),
      projectId: (j['projectId'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      priority: (j['priority'] ?? 'medium').toString(),
      status: (j['status'] ?? 'todo').toString(),
      assigneeId: j['assigneeId']?.toString(),
      dueDate: rawDue,
      labels: j['labels'] is List
          ? (j['labels'] as List).map((e) => e.toString()).toList()
          : const [],
      order: j['order'] is num ? (j['order'] as num).toInt() : 0,
      createdAt: j['createdAt']?.toString(),
      updatedAt: j['updatedAt']?.toString(),
      due: parseDate(rawDue),
    );
  }

  DateTime? get created => parseDate(createdAt);

  TaskModel copyWith({
    String? title,
    String? description,
    String? priority,
    String? status,
    String? assigneeId,
    String? dueDate,
    List<String>? labels,
    int? order,
    DateTime? due,
  }) {
    return TaskModel(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assigneeId: assigneeId ?? this.assigneeId,
      dueDate: dueDate ?? this.dueDate,
      labels: labels ?? this.labels,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt,
      due: due ?? this.due,
    );
  }
}