// services/personalization_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalizationService extends ChangeNotifier {

  /// Check if personalization is already completed for a user.
  /// Falls back to SharedPreferences if Firestore fails (e.g. first launch offline).
  Future<bool> isPersonalizationCompleted(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('personalization')
        .doc('data')
        .get();
      return doc.data()?['isCompleted'] ?? false;
    } catch (e) {
      debugPrint('Personalization check failed, falling back to SharedPreferences: $e');
      // Fallback to SharedPreferences if Firestore fails
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('personalization_completed') ?? false;
    }
  }

  /// Save personalization selections to Firestore.
  Future<void> savePersonalizationData({
    required String email,
    required List<String> genres,
    required List<String> artists,
    required List<String> moods,
  }) async {
    try {
      final data = {
        'userId': email,
        'genres': genres,
        'artists': artists,
        'moods': moods,
        'completedAt': FieldValue.serverTimestamp(),
        'isCompleted': true,
      };

      await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('personalization')
        .doc('data')
        .set(data);

      debugPrint('Personalization data saved to Firestore for $email');
    } catch (e) {
      debugPrint('Error saving personalization data: $e');
      rethrow;
    }
  }

  /// Mark personalization as completed without saving data (e.g. if skipped).
  Future<void> setPersonalizationCompleted(String email) async {
    try {
      await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('personalization')
        .doc('data')
        .set({'isCompleted': true}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting personalization completed: $e');
    }
  }

  /// Reset personalization (for testing/debugging).
  Future<void> resetPersonalization(String email) async {
    try {
      await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('personalization')
        .doc('data')
        .delete();
    } catch (e) {
      debugPrint('Error resetting personalization: $e');
    }
  }

  /// Get personalization data for a user.
  Future<Map<String, dynamic>?> getPersonalizationData(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('personalization')
        .doc('data')
        .get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting personalization data: $e');
      return null;
    }
  }
}
