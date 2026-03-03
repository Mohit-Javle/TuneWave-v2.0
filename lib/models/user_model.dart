import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String name;
  final String email;
  final String? imageUrl;
  final Map<String, dynamic>? followedArtists;

  UserModel({
    required this.name,
    required this.email,
    this.imageUrl,
    this.followedArtists,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      imageUrl: json['imageUrl'],
      followedArtists: json['followedArtists'],
    );
  }

  factory UserModel.fromFirebase(User firebaseUser, Map<String, dynamic>? firestoreData) {
    return UserModel(
      name: firestoreData?['name'] ?? firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      imageUrl: firestoreData?['imageUrl'] ?? firebaseUser.photoURL,
      followedArtists: firestoreData?['followedArtists'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'imageUrl': imageUrl,
      'followedArtists': followedArtists,
    };
  }
}
