import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/async_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/data/dashboard_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _name.text = user?.fullName ?? '';
    _username.text = user?.username ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).dio.patch('/users/me', data: {
        'fullName': _name.text.trim(),
        'username': _username.text.trim(),
      });
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) showSnack(context, 'Đã cập nhật hồ sơ');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return;
    try {
      final name = picked.name.toLowerCase();
      final subtype = name.endsWith('.png')
          ? 'png'
          : name.endsWith('.webp')
              ? 'webp'
              : 'jpeg';
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          picked.path,
          filename: picked.name,
          contentType: DioMediaType('image', subtype),
        ),
      });
      await ref.read(apiClientProvider).dio.patch('/users/me/avatar', data: form);
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) showSnack(context, 'Đã đổi ảnh đại diện');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();

    final stats = ref.watch(dashboardProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hồ sơ cá nhân',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Center(
          child: Stack(
            children: [
              AppAvatar(
                name: user.fullName,
                url: user.avatarUrl == null ? null : AppConstants.resolveUrl(user.avatarUrl!),
                radius: 48,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: IconButton.filled(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.camera_alt_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Họ và tên')),
        const SizedBox(height: 12),
        TextField(
          controller: _username,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Email'),
          child: Text(user.email),
        ),
        const SizedBox(height: 20),
        stats.when(
          data: (x) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('${x.completedThisWeek}', 'Hoàn tất 7 ngày'),
                  _stat('${x.completionRate}%', 'Tỷ lệ hoàn tất'),
                ],
              ),
            ),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lưu thay đổi'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        Text(label),
      ],
    );
  }
}
