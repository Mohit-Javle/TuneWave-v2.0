import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clone_mp/services/auth_service.dart';

class PersonalizationService extends ChangeNotifier {
  static const String _completedKey = 'personalization_completed';
  static const String _dataKey = 'personalization_data';

  // Check if personalization is already completed (locally)
  Future<bool> isPersonalizationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    // Check if the flag is set to true
    return prefs.getBool(_completedKey) ?? false;
  }

  // Save personalization selections to SharedPreferences 
  // (Mocking Firestore behavior as requested, since cloud_firestore is not in dependencies)
  Future<void> savePersonalizationData({
    required List<String> genres,
    required List<String> artists,
    required List<String> moods,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      debugPrint("Error: No user logged in to save personalization data.");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create data map
      final data = {
        'userId': user.email, // using email as ID since that's what AuthService uses
        'genres': genres,
        'artists': artists,
        'moods': moods,
        'completedAt': DateTime.now().toIso8601String(),
        'isCompleted': true,
      };

      // Save data locally
      await prefs.setString(_dataKey, jsonEncode(data));

      // Set completed flag
      await prefs.setBool(_completedKey, true);
      
      debugPrint("Personalization data saved successfully (Local Mock).");
    } catch (e) {
      debugPrint("Error saving personalization data: $e");
      rethrow;
    }
  }

  // Mark as completed without saving data (e.g. if skipped)
  Future<void> setPersonalizationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }

  // Reset personalization (for testing/debugging)
  Future<void> resetPersonalization() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedKey);
    await prefs.remove(_dataKey);
  }
}
