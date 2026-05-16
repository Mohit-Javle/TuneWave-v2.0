import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? imageUrl;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.imageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }

  factory UserModel.fromFirebase(User firebaseUser, Map<String, dynamic>? firestoreData) {
    return UserModel(
      uid: firebaseUser.uid,
      name: firestoreData?['name'] ?? firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      imageUrl: firestoreData?['imageUrl'] ?? firebaseUser.photoURL,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'imageUrl': imageUrl,
    };
  }
}
