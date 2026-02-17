// lib/services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:clone_mp/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _usersKey = 'users_db';
  static const String _sessionKey = 'current_user_email';

  // Load session on startup
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final currentEmail = prefs.getString(_sessionKey);

    if (currentEmail != null) {
      final usersJson = prefs.getString(_usersKey);
      if (usersJson != null) {
        final Map<String, dynamic> users = jsonDecode(usersJson);
        debugPrint("DEBUG AUTH: Loaded existing users: $usersJson");
        if (users.containsKey(currentEmail)) {
          _currentUser = UserModel.fromJson(users[currentEmail]);
          _userController.add(_currentUser);
          notifyListeners();
        }
      }
    }
  }

  // Register a new user
  Future<String?> register(String name, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    Map<String, dynamic> users = {};
    
    if (usersJson != null) {
      users = jsonDecode(usersJson);
    }

    if (users.containsKey(email)) {
      return "User already exists with this email.";
    }

    final newUser = UserModel(
      name: name,
      email: email,
      password: password,
      imageUrl: null, // Default or allow setting later
    );

    users[email] = newUser.toJson();
    await prefs.setString(_usersKey, jsonEncode(users));
    debugPrint("DEBUG AUTH: Database updated. Current users: ${jsonEncode(users)}");
    
    // Auto login after register
    await _setSession(newUser);
    return null; // Success
  }

  // Login existing user
  Future<String?> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    
    if (usersJson == null) return "No users registered.";
    
    final Map<String, dynamic> users = jsonDecode(usersJson);
    if (!users.containsKey(email)) {
      return "User not found.";
    }

    final userMap = users[email];
    if (userMap['password'] != password) {
      return "Incorrect password.";
    }

    final user = UserModel.fromJson(userMap);
    await _setSession(user);
    return null; // Success
  }

  Future<void> _setSession(UserModel user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, user.email);
    _userController.add(_currentUser);
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    // We DON'T remove the user from _usersKey (that would delete the account)
    
    _userController.add(null);
    notifyListeners();
  }

  // Update profile
  Future<void> updateUserProfile({
    required String newName,
    String? newImageUrl,
  }) async {
    if (_currentUser != null) {
      final updatedUser = UserModel(
        name: newName,
        email: _currentUser!.email,
        password: _currentUser!.password,
        imageUrl: newImageUrl ?? _currentUser!.imageUrl,
      );

      _currentUser = updatedUser;
      
      // Update in DB
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      if (usersJson != null) {
        Map<String, dynamic> users = jsonDecode(usersJson);
        users[_currentUser!.email] = _currentUser!.toJson();
        await prefs.setString(_usersKey, jsonEncode(users));
      }
      
      _userController.add(_currentUser);
      notifyListeners();
    }
  }
}
