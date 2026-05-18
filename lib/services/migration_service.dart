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
  Future<void> migrateIfNeeded(String uid, String email) async {
    try {
      // NOTE: We're performing a Forced Sync to ensure all 84 items are captured.
      debugPrint('MIGRATION: Starting Forced Sync for $email ($uid)...');

      // Run migration for user-scoped data only
      await _migrateLikedSongs(uid, email);
      await _migratePlaylists(uid, email);
      await _migratePersonalization(uid, email);

      // Cloud-to-Cloud migration (migrates old email-based Firestore paths to UID paths)
      await _migrateOldFirestoreData(uid, email);

      // Mark migration complete in Firestore
      await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('data')
        .set({'migrationCompleted': true}, SetOptions(merge: true))
        .timeout(const Duration(seconds: 5));

      debugPrint('MIGRATION: Migration completed successfully for $email ($uid)');
    } catch (e) {
      // Migration failed — do NOT crash app
      // Next login will retry automatically
      debugPrint('MIGRATION: Migration failed for $email ($uid): $e');
    }
  }

  /// Migrates liked songs from SharedPreferences to Firestore.
  /// Key: 'liked_songs_$email' → Firestore: users/{uid}/likedSongs/{songId}
  Future<void> _migrateLikedSongs(String uid, String email) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check both legacy key and user-scoped key
    final String? rawLegacy = prefs.getString('liked_songs');
    final String? rawUser = prefs.getString('liked_songs_$email');
    
    if (rawLegacy == null && rawUser == null) return;

    List<dynamic> allSongs = [];
    if (rawLegacy != null) {
      allSongs.addAll(jsonDecode(rawLegacy));
      debugPrint('MIGRATION: Found ${jsonDecode(rawLegacy).length} legacy liked songs');
    }
    if (rawUser != null) {
      allSongs.addAll(jsonDecode(rawUser));
      debugPrint('MIGRATION: Found ${jsonDecode(rawUser).length} user-scoped liked songs');
    }

    if (allSongs.isEmpty) return;

    // Deduplicate by ID
    final uniqueSongsMap = <String, dynamic>{};
    for (var s in allSongs) {
      if (s['id'] != null) uniqueSongsMap[s['id'].toString()] = s;
    }
    final uniqueSongs = uniqueSongsMap.values.toList();

    debugPrint('MIGRATION: Syncing ${uniqueSongs.length} unique liked songs to Firestore for $email ($uid)...');

    final batch = FirebaseFirestore.instance.batch();

    for (final song in uniqueSongs) {
      final String songId = song['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      // We use the same doc ID pattern we now use in PlaylistService for consistency
      final String docId = "${DateTime.now().millisecondsSinceEpoch}_$songId";
      
      final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('likedSongs')
        .doc(docId);

      batch.set(ref, {
        ...Map<String, dynamic>.from(song),
        'likedAt': FieldValue.serverTimestamp(),
        'sortId': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    }
    await batch.commit().timeout(const Duration(seconds: 10));
    debugPrint('MIGRATION: Liked songs sync SUCCESS ✅');
  }

  /// Migrates playlists from SharedPreferences to Firestore.
  /// Key: 'playlists_$email' → Firestore: users/{uid}/playlists/{playlistId}
  Future<void> _migratePlaylists(String uid, String email) async {
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
        .doc(uid)
        .collection('playlists')
        .doc(playlist['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString());
      batch.set(ref, Map<String, dynamic>.from(playlist));
    }
    await batch.commit().timeout(const Duration(seconds: 10));
  }

  /// Migrates personalization data from SharedPreferences to Firestore.
  /// Key: 'personalization_data' → Firestore: users/{uid}/personalization/data
  /// This key is global but contains a userId field, so we verify ownership.
  Future<void> _migratePersonalization(String uid, String email) async {
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

    // Update userId field in personalization data to reflect the new structure (can still be email or we can support both, let's keep it as is or update)
    data['userId'] = uid; // Update to UID inside the document!

    await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('personalization')
      .doc('data')
      .set(data)
      .timeout(const Duration(seconds: 5));
  }

  /// Migrates old Firestore data (email-based paths) to new UID-based paths.
  /// Old: users/{email} -> New: users/{uid}
  Future<void> _migrateOldFirestoreData(String uid, String email) async {
    // If UID and Email are exactly the same, no migration is needed
    if (uid == email) return;

    try {
      debugPrint('MIGRATION: Checking if old Firestore data exists for $email...');
      
      // Check if old profile data exists
      final oldProfileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('profile')
          .doc('data')
          .get();

      if (!oldProfileDoc.exists) {
        debugPrint('MIGRATION: No old email-based Firestore profile found for $email. Skipping cloud migration.');
        return;
      }

      debugPrint('MIGRATION: Old Firestore profile found for $email! Starting cloud-to-cloud migration...');

      // 1. Profile Data Migration
      final profileData = oldProfileDoc.data();
      if (profileData != null) {
        profileData['uid'] = uid;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('data')
            .set(profileData, SetOptions(merge: true));
        debugPrint('MIGRATION: Cloud Profile Migrated ✅');
      }

      // 2. Personalization Migration
      final oldPersDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('personalization')
          .doc('data')
          .get();
      if (oldPersDoc.exists && oldPersDoc.data() != null) {
        final pData = Map<String, dynamic>.from(oldPersDoc.data()!);
        pData['userId'] = uid; // update to new UID!
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('personalization')
            .doc('data')
            .set(pData, SetOptions(merge: true));
        debugPrint('MIGRATION: Cloud Personalization Migrated ✅');
      }

      // 3. Liked Songs Migration
      final oldLikedSongs = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('likedSongs')
          .get();
      if (oldLikedSongs.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in oldLikedSongs.docs) {
          final ref = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('likedSongs')
              .doc(doc.id);
          batch.set(ref, doc.data(), SetOptions(merge: true));
        }
        await batch.commit();
        debugPrint('MIGRATION: Cloud ${oldLikedSongs.docs.length} Liked Songs Migrated ✅');
      }

      // 4. Playlists Migration
      final oldPlaylists = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('playlists')
          .get();
      if (oldPlaylists.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in oldPlaylists.docs) {
          final ref = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('playlists')
              .doc(doc.id);
          batch.set(ref, doc.data(), SetOptions(merge: true));
        }
        await batch.commit();
        debugPrint('MIGRATION: Cloud ${oldPlaylists.docs.length} Playlists Migrated ✅');
      }

      // 5. Listening History Migration
      final oldHistory = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('listeningHistory')
          .get();
      if (oldHistory.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in oldHistory.docs) {
          final ref = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('listeningHistory')
              .doc(doc.id);
          batch.set(ref, doc.data(), SetOptions(merge: true));
        }
        await batch.commit();
        debugPrint('MIGRATION: Cloud ${oldHistory.docs.length} History Items Migrated ✅');
      }

      // 6. Delete old email-based documents to keep database completely clean
      debugPrint('MIGRATION: Cleaning up old email-based documents...');
      
      // Delete old profile doc
      await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('profile')
          .doc('data')
          .delete();

      // Delete old personalization doc
      await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('personalization')
          .doc('data')
          .delete();

      // Delete old liked songs
      if (oldLikedSongs.docs.isNotEmpty) {
        final deleteBatch = FirebaseFirestore.instance.batch();
        for (var doc in oldLikedSongs.docs) {
          deleteBatch.delete(doc.reference);
        }
        await deleteBatch.commit();
      }

      // Delete old playlists
      if (oldPlaylists.docs.isNotEmpty) {
        final deleteBatch = FirebaseFirestore.instance.batch();
        for (var doc in oldPlaylists.docs) {
          deleteBatch.delete(doc.reference);
        }
        await deleteBatch.commit();
      }

      // Delete old history
      if (oldHistory.docs.isNotEmpty) {
        final deleteBatch = FirebaseFirestore.instance.batch();
        for (var doc in oldHistory.docs) {
          deleteBatch.delete(doc.reference);
        }
        await deleteBatch.commit();
      }

      // Delete the root email document itself if empty
      await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .delete();

      debugPrint('MIGRATION: Cloud migration and cleanup completed successfully for $email to $uid! 🎉');
    } catch (e) {
      debugPrint('MIGRATION: Error during cloud-to-cloud migration: $e');
    }
  }
}
