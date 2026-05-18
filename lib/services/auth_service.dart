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
<<<<<<< HEAD
      _currentUser = await _fetchUserProfile(firebaseUser.email!);
      
      // FALLBACK: If Firestore profile fetch failed (offline), create a minimal profile 
      // from Firebase Auth data so the app doesn't show "Not logged in".
      if (_currentUser == null) {
        debugPrint("AuthService: Firestore profile fetch failed, using fallback from Firebase Auth.");
        _currentUser = UserModel(
          name: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
          email: firebaseUser.email!,
          imageUrl: firebaseUser.photoURL ?? '',
        );
      }
      
=======
      _currentUser = await _fetchUserProfile(firebaseUser.uid, firebaseUser.email!);
      if (_currentUser == null) {
        _currentUser = UserModel(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName ?? 'User',
            email: firebaseUser.email!,
            imageUrl: firebaseUser.photoURL ?? '');
      }
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df
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
<<<<<<< HEAD
  
  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Google Sign In
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // Force account selection dialog
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User canceled the sign-in flow
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;
      
      if (firebaseUser != null) {
        UserModel? userData = await _fetchUserProfile(firebaseUser.email!);
        
        // If user profile doesn't exist (new user via Google), create it
        if (userData == null) {
          final String name = firebaseUser.displayName ?? firebaseUser.email!.split('@')[0];
          final String email = firebaseUser.email!;
          final String photoUrl = firebaseUser.photoURL ?? '';
          
          await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .collection('profile')
            .doc('data')
            .set({
              'name': name,
              'email': email,
              'imageUrl': photoUrl,
              'createdAt': FieldValue.serverTimestamp(),
            });
            
          userData = UserModel(name: name, email: email, imageUrl: photoUrl);
        }
        
        _currentUser = userData;
        _userController.add(_currentUser);
        notifyListeners();
        return userData;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      debugPrint("Error in Google Sign In: $e");
      throw "An error occurred during Google Sign In.";
    }
  }

  // Register alias for signUp() - throws exception on failure
=======

  // Register alias for signUp()
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df
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
<<<<<<< HEAD
      final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('profile')
        .doc('data')
        .get()
        .timeout(const Duration(seconds: 10));
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
=======
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
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user profile (might be offline): $e");
      // Return null or handle based on app needs. 
      // SplashScreen now handles the null case by proceeding with email-only session.
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
<<<<<<< HEAD
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
=======
      // Update Firebase Auth Profile
      if (newName != user.displayName) {
        await user.updateDisplayName(newName);
      }
      if (newImageUrl != null && newImageUrl != user.photoURL) {
        await user.updatePhotoURL(newImageUrl);
      }
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df

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
<<<<<<< HEAD

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
=======
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df
}
