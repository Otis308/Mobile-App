class CommentModel {
  final String id;
  final String taskId;
  final String authorId;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> j) => CommentModel(
        id: (j['_id'] ?? '').toString(),
        taskId: (j['taskId'] ?? '').toString(),
        authorId: (j['authorId'] ?? '').toString(),
        content: (j['content'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      );
}
