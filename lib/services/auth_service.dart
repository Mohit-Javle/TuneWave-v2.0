import 'dart:async';
import 'package:clone_mp/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      _currentUser = await _fetchUserProfile(firebaseUser.uid, firebaseUser.email!);
      if (_currentUser == null) {
        _currentUser = UserModel(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName ?? 'User',
            email: firebaseUser.email!,
            imageUrl: firebaseUser.photoURL ?? '');
      }
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

      // Send email verification
      await cred.user?.sendEmailVerification();

      // Save profile to Firestore
      final uid = cred.user!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('data')
          .set({
        'uid': uid,
        'name': name,
        'email': email,
        'imageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final user = UserModel(uid: uid, name: name, email: email, imageUrl: '');
      _currentUser = user;
      _userController.add(_currentUser);
      notifyListeners();
      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Sign In
  Future<UserModel?> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      var userData = await _fetchUserProfile(uid, email);
      if (userData == null) {
        userData = UserModel(
            uid: uid,
            name: FirebaseAuth.instance.currentUser!.displayName ?? 'User',
            email: email,
            imageUrl: FirebaseAuth.instance.currentUser!.photoURL ?? '');
      }
      _currentUser = userData;
      _userController.add(_currentUser);
      notifyListeners();
      return userData;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Sign In with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      final GoogleSignInAccount? googleUser = await signIn.authenticate();
      if (googleUser == null) return null; // The user canceled the sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential cred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = cred.user;
      if (firebaseUser == null) {
        throw FirebaseAuthException(
            code: 'sign-in-failed', message: 'Failed to sign in with Google.');
      }

      final uid = firebaseUser.uid;
      final email = firebaseUser.email ?? '';
      final name = firebaseUser.displayName ?? 'User';
      final imageUrl = firebaseUser.photoURL ?? '';

      UserModel? userData;

      if (cred.additionalUserInfo?.isNewUser == true) {
        // Create Firestore profile
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('data')
            .set({
          'uid': uid,
          'name': name,
          'email': email,
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
        userData =
            UserModel(uid: uid, name: name, email: email, imageUrl: imageUrl);
      } else {
        // Fetch existing
        userData = await _fetchUserProfile(uid, email);
        if (userData == null) {
          userData =
              UserModel(uid: uid, name: name, email: email, imageUrl: imageUrl);
        }
      }

      _currentUser = userData;
      _userController.add(_currentUser);
      notifyListeners();
      return userData;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Sign Out
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _currentUser = null;
    _userController.add(null);
    notifyListeners();
  }

  // Compatibility alias for logout()
  Future<void> signOut() async {
    await logout();
  }

  // Register alias for signUp()
  Future<UserModel?> register(String name, String email, String password) {
    return signUp(name, email, password);
  }

  // Login alias for signIn()
  Future<UserModel?> login(String email, String password) {
    return signIn(email, password);
  }

  // Fetch profile from Firestore
  Future<UserModel?> _fetchUserProfile(String uid, String email) async {
    try {
      var ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('data');

      var snap = await ref.get();

      // Fallback: old email-keyed doc (remove after migration is stable)
      if (!snap.exists) {
        ref = FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .collection('profile')
            .doc('data');
        snap = await ref.get();
      }

      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        data['uid'] = uid; // Ensure uid is present even from legacy docs
        return UserModel.fromJson(data);
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
          .doc(_currentUser!.uid)
          .collection('profile')
          .doc('data')
          .update(updates);

      // Update local state
      _currentUser = UserModel(
          uid: _currentUser!.uid,
          name: newName,
          email: _currentUser!.email,
          imageUrl: newImageUrl ?? _currentUser!.imageUrl);

      _userController.add(_currentUser);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating profile: $e");
      throw "Failed to update profile";
    }
  }
}
