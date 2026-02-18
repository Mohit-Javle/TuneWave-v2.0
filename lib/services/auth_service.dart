import 'dart:async';
import 'package:clone_mp/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  // Singleton pattern
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  final StreamController<UserModel?> _userController =
      StreamController<UserModel?>.broadcast();
  Stream<UserModel?> get userStream => _userController.stream;

  // Init — called on app start
  Future<void> init() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null && firebaseUser.email != null) {
      _currentUser = await _fetchUserProfile(firebaseUser.email!);
      _userController.add(_currentUser);
      notifyListeners();
    }
  }

  // Sign Up
  Future<UserModel?> signUp(String name, String email, String password) async {
    try {
      UserCredential cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
      
      await cred.user?.updateDisplayName(name);
      
      // Save profile to Firestore
      await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('profile')
        .doc('data')
        .set({
          'name': name,
          'email': email,
          'imageUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      
      final user = UserModel(name: name, email: email, imageUrl: '');
      _currentUser = user;
      _userController.add(_currentUser);
      notifyListeners();
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign In
  Future<UserModel?> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
      final userData = await _fetchUserProfile(email);
      _currentUser = userData;
      _userController.add(_currentUser);
      notifyListeners();
      return userData;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign Out
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _currentUser = null;
    _userController.add(null);
    notifyListeners();
  }

  // Compatibility alias for logout() if needed, but existing code calls logout()
  Future<void> signOut() async {
    await logout();
  }
  
  // Register alias for signUp() - throws exception on failure
  Future<UserModel?> register(String name, String email, String password) {
    return signUp(name, email, password);
  }

  // Login alias for signIn() - throws exception on failure
  Future<UserModel?> login(String email, String password) {
    return signIn(email, password);
  }

  // Fetch profile from Firestore
  Future<UserModel?> _fetchUserProfile(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('profile')
        .doc('data')
        .get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      return null;
    }
  }

  // Update profile (needed for ProfileScreen)
  Future<void> updateUserProfile({
    required String newName,
    String? newImageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentUser == null) return;

    try {
       // Update Firebase Auth Profile
       if (newName != user.displayName) {
         await user.updateDisplayName(newName);
       }
       if (newImageUrl != null && newImageUrl != user.photoURL) {
         await user.updatePhotoURL(newImageUrl);
       }

       // Update Firestore
       final updates = <String, dynamic>{
         'name': newName,
       };
       if (newImageUrl != null) {
         updates['imageUrl'] = newImageUrl;
       }

       await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.email)
        .collection('profile')
        .doc('data')
        .update(updates);

       // Update local state
       _currentUser = UserModel(
         name: newName, 
         email: _currentUser!.email, 
         imageUrl: newImageUrl ?? _currentUser!.imageUrl
       );
       
       _userController.add(_currentUser);
       notifyListeners();

    } catch (e) {
      debugPrint("Error updating profile: $e");
      throw "Failed to update profile";
    }
  }

  // Handle Firebase errors with readable messages
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'network-request-failed': return 'No internet connection.';
      default: return 'Something went wrong. Please try again.';
    }
  }
}
