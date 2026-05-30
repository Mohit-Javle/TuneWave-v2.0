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

      // 1. Root Level Document (For easy Firestore console sorting)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'uid': uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Subcollection Level Document
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
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      await googleSignIn.signOut(); // Force account selection dialog
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      if (googleUser == null) return null; // The user canceled the sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: null,
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
        // 1. Create root Firestore profile
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
          'uid': uid,
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Create subcollection profile
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
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      debugPrint("Error in Google Sign In: $e");
      throw "An error occurred during Google Sign In.";
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

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
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

      var snap = await ref.get().timeout(const Duration(seconds: 10));

      // Fallback: old email-keyed doc (remove after migration is stable)
      if (!snap.exists) {
        ref = FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .collection('profile')
            .doc('data');
        snap = await ref.get().timeout(const Duration(seconds: 10));
      }

      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        data['uid'] = uid; // Ensure uid is present even from legacy docs
        return UserModel.fromJson(data, uid);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user profile (might be offline): $e");
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
      // Firebase Auth's photoURL has a length limit and will crash if given a large Base64 string.
      // Only save standard http/https URLs to the Auth user, but save everything (including Base64) to Firestore.
      if (newImageUrl != null && newImageUrl != user.photoURL) {
        if (!newImageUrl.startsWith('data:image')) {
          await user.updatePhotoURL(newImageUrl);
        }
      }

      // Update Firestore root
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'name': newName,
      });

      // Update Firestore profile/data subcollection
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

  // Handle Firebase errors with readable messages
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential': return 'Invalid email or password.';
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'network-request-failed': return 'No internet connection.';
      default: return 'Something went wrong (${e.code}). Please try again.';
    }
  }
}
