class AdminModel {
  final String id;
  final String name;
  final String email;
  final String password;
  final String companyName;
  final DateTime createdAt;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.companyName,
    required this.password,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AdminModel.fromJson(Map<String, dynamic> json) => AdminModel(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    companyName: json['companyName'],
    password: json['password'],
    createdAt: DateTime.parse(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'companyName': companyName,
    'password': password,
    'createdAt': createdAt.toIso8601String(),
  };
}
