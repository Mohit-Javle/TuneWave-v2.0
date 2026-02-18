// services/migration_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MigrationService {

  /// Migrates user-scoped SharedPreferences data to Firestore.
  /// Only migrates keys that are already scoped to the user's email.
  /// Global keys (listening_history, followed_artists, etc.) are skipped
  /// because we cannot safely determine which user they belong to.
  ///
  /// Safe pattern:
  /// 1. READ from SharedPreferences
  /// 2. WRITE to Firestore
  /// 3. VERIFY write succeeded
  /// 4. Set migration flag in Firestore
  /// 5. SharedPreferences data is NOT deleted (kept as fallback)
  Future<void> migrateIfNeeded(String email) async {
    try {
      // Check if already migrated in Firestore
      final profileDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('profile')
        .doc('data')
        .get();

      if (profileDoc.data()?['migrationCompleted'] == true) return;

      debugPrint('MIGRATION: Starting migration for $email');

      // Run migration for user-scoped data only
      await _migrateLikedSongs(email);
      await _migratePlaylists(email);
      await _migratePersonalization(email);

      // Mark migration complete in Firestore
      await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('profile')
        .doc('data')
        .set({'migrationCompleted': true}, SetOptions(merge: true));

      debugPrint('MIGRATION: Migration completed successfully for $email');
    } catch (e) {
      // Migration failed — do NOT crash app
      // Next login will retry automatically
      debugPrint('MIGRATION: Migration failed for $email: $e');
    }
  }

  /// Migrates liked songs from SharedPreferences to Firestore.
  /// Key: 'liked_songs_$email' → Firestore: users/{email}/likedSongs/{songId}
  Future<void> _migrateLikedSongs(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('liked_songs_$email');
    if (raw == null) return;

    final List<dynamic> songs = jsonDecode(raw);
    if (songs.isEmpty) return;

    debugPrint('MIGRATION: Migrating ${songs.length} liked songs');

    final batch = FirebaseFirestore.instance.batch();

    for (final song in songs) {
      final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('likedSongs')
        .doc(song['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString());
      batch.set(ref, {
        ...Map<String, dynamic>.from(song),
        'likedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Migrates playlists from SharedPreferences to Firestore.
  /// Key: 'playlists_$email' → Firestore: users/{email}/playlists/{playlistId}
  Future<void> _migratePlaylists(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('playlists_$email');
    if (raw == null) return;

    final List<dynamic> playlists = jsonDecode(raw);
    if (playlists.isEmpty) return;

    debugPrint('MIGRATION: Migrating ${playlists.length} playlists');

    final batch = FirebaseFirestore.instance.batch();

    for (final playlist in playlists) {
      final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('playlists')
        .doc(playlist['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString());
      batch.set(ref, Map<String, dynamic>.from(playlist));
    }
    await batch.commit();
  }

  /// Migrates personalization data from SharedPreferences to Firestore.
  /// Key: 'personalization_data' → Firestore: users/{email}/personalization/data
  /// This key is global but contains a userId field, so we verify ownership.
  Future<void> _migratePersonalization(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('personalization_data');
    if (raw == null) return;

    final Map<String, dynamic> data = jsonDecode(raw);

    // Verify this data belongs to this user
    if (data['userId'] != email) {
      debugPrint('MIGRATION: Personalization data belongs to ${data['userId']}, not $email. Skipping.');
      return;
    }

    debugPrint('MIGRATION: Migrating personalization data');

    await FirebaseFirestore.instance
      .collection('users')
      .doc(email)
      .collection('personalization')
      .doc('data')
      .set(data);
  }
}
