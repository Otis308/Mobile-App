import 'package:flutter/material.dart';

import '../../../../core/utils/json_utils.dart';

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final String color;
  final String ownerId;
  final List<Map<String, dynamic>> members;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.ownerId,
    required this.members,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> j) => ProjectModel(
        id: (j['_id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        color: (j['color'] ?? '3E6FF2').toString(),
        ownerId: (j['ownerId'] ?? '').toString(),
        members: asMapList(j['members']),
      );

  Color get colorValue {
    final hex = color.replaceAll('#', '');
    final value = int.tryParse('FF$hex', radix: 16);
    return Color(value ?? 0xFF3E6FF2);
  }

  /// userId -> role (owner/manager/member)
  Map<String, String> get roleByUser => {
        for (final m in members) m['userId'].toString(): (m['role'] ?? 'member').toString(),
      };
}
