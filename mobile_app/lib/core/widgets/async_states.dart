import 'package:flutter/material.dart';

import '../errors/app_exception.dart';

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: 12),
            Text(errorMessage(error), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

const taskStatusLabels = {
  'todo': 'Cần làm',
  'doing': 'Đang làm',
  'review': 'Đang review',
  'done': 'Hoàn tất',
};

const taskPriorityLabels = {
  'low': 'Thấp',
  'medium': 'Vừa',
  'high': 'Cao',
  'urgent': 'Khẩn',
};
