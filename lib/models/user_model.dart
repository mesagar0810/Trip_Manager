class UserModel {
  final String id;
  final String userName;
  final String role; // 'user' (driver) or 'admin'
  final DateTime createdAt;

  UserModel({required this.id, required this.userName, required this.role, required this.createdAt});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    userName: json['user_name'],
    role: json['role'],
    createdAt: DateTime.parse(json['created_at']),
  );

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'user';
}
