class UserModel {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        fullName: (j['fullName'] ?? '').toString(),
        role: (j['role'] ?? 'member').toString(),
        avatarUrl: j['avatarUrl']?.toString(),
      );
}
