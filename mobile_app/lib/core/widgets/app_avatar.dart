import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const AppAvatar({super.key, this.url, required this.name, this.radius = 22});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    final text = parts.map((x) => x[0]).take(2).join().toUpperCase();
    return text.isEmpty ? '?' : text;
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasImage ? NetworkImage(url!) : null,
      child: hasImage ? null : Text(_initials),
    );
  }
}
