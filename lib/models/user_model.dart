// lib/models/user_model.dart

class UserModel {
  final String name;
  final String email;
  final String? password; // For local auth
  final String? imageUrl;

  UserModel({
    required this.name,
    required this.email,
    this.password,
    this.imageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'],
      email: json['email'],
      password: json['password'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'imageUrl': imageUrl,
    };
  }
}
