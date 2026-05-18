import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? imageUrl;
  final Map<String, dynamic>? followedArtists;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.imageUrl,
    this.followedArtists,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
<<<<<<< HEAD
      uid: uid,
=======
      uid: json['uid'] ?? '',
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      imageUrl: json['imageUrl'],
      followedArtists: json['followedArtists'],
    );
  }

  factory UserModel.fromFirebase(User firebaseUser, Map<String, dynamic>? firestoreData) {
    return UserModel(
      uid: firebaseUser.uid,
      name: firestoreData?['name'] ?? firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      imageUrl: firestoreData?['imageUrl'] ?? firebaseUser.photoURL,
      followedArtists: firestoreData?['followedArtists'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'imageUrl': imageUrl,
      'followedArtists': followedArtists,
    };
  }
}
