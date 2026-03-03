import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clone_mp/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FollowService extends ChangeNotifier {
  // Map of artistId -> {id, name, image}
  Map<String, Map<String, String>> _followedArtists = {};
  
  List<String> get followedArtistIds => _followedArtists.keys.toList();
  int get followingCount => _followedArtists.length;
  List<Map<String, String>> get followedArtistsList => _followedArtists.values.toList();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;

  FollowService() {
    _init();
  }

  Future<void> _init() async {
    await _loadFollowedArtists();
    
    // Check if user is already logged in (it may have been emitted before we subscribed)
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      await _syncWithFirestore(currentUser.email);
    }
    
    // Listen for auth changes to sync with Firestore
    _authService.userStream.listen((user) async {
      if (user != null) {
        await _syncWithFirestore(user.email);
      } else {
        _followedArtists.clear();
        await _loadFollowedArtists(); // Reload local data for guest if any
      }
    });
  }

  Future<void> _loadFollowedArtists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString('followed_artists_metadata');
    if (encoded != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(encoded);
        _followedArtists = decoded.map((key, value) => 
          MapEntry(key, Map<String, String>.from(value))
        );
      } catch (e) {
        debugPrint("Error decoding local followed artists: $e");
      }
    } else {
      final oldList = prefs.getStringList('followed_artists') ?? [];
      for (var id in oldList) {
        _followedArtists[id] = {'id': id, 'name': 'Artist', 'image': ''};
      }
    }
    notifyListeners();
  }

  Future<void> _syncWithFirestore(String email) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(email)
          .collection('profile')
          .doc('data')
          .get();
      if (doc.exists && doc.data()?.containsKey('followedArtists') == true) {
        final Map<String, dynamic> firestoreFollows = doc.data()!['followedArtists'];
        
        // Merge with local (Cloud takes precedence for consistency, but we merge to be safe)
        firestoreFollows.forEach((key, value) {
          _followedArtists[key] = Map<String, String>.from(value as Map);
        });
        
        await _saveFollowedArtists(); // Sync back to local Cache
      } else {
        // If Firestore is empty but Local has data, sync local to Firestore
        if (_followedArtists.isNotEmpty) {
          await _updateFirestoreWholeMap(email);
        }
      }
    } catch (e) {
      debugPrint("Error syncing follows with Firestore: $e");
    }
  }

  Future<void> _updateFirestoreWholeMap(String email) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(email)
          .collection('profile')
          .doc('data');
          
      // Using set with merge: true for the top-level field 'followedArtists'. 
      // This will replace the entire 'followedArtists' map in Firestore with our local _followedArtists map,
      // without affecting other fields in the document like 'name' or 'imageUrl'.
      // It also handles the case where the document doesn't exist yet by creating it.
      await docRef.set({
        'followedArtists': _followedArtists,
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint("Error updating Firestore follows whole map: $e");
    }
  }

  Future<void> _updateFirestoreSingleArtist(String email, String artistId, Map<String, String>? artistData) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(email)
          .collection('profile')
          .doc('data');

      if (artistData == null) {
        // Remove from Firestore
        await docRef.update({
          'followedArtists.$artistId': FieldValue.delete(),
        }).catchError((e) {
          debugPrint("Doc might not exist for unfollow: $e");
        });
      } else {
        // Add/Update in Firestore
        await docRef.set({
          'followedArtists': {
            artistId: artistData
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error updating single artist in Firestore: $e");
    }
  }

  Future<void> _saveFollowedArtists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('followed_artists_metadata', json.encode(_followedArtists));
    notifyListeners();
  }

  bool isFollowing(String artistId) {
    return _followedArtists.containsKey(artistId);
  }

  void toggleFollow(String artistId, {String? name, String? image}) {
    Map<String, String>? artistData;
    
    if (_followedArtists.containsKey(artistId)) {
      _followedArtists.remove(artistId);
      artistData = null;
    } else {
      artistData = {
        'id': artistId,
        'name': (name != null && name.isNotEmpty) ? name : 'Unknown',
        'image': image ?? '',
      };
      _followedArtists[artistId] = artistData;
    }
    
    _saveFollowedArtists();

    // If logged in, sync to cloud
    final user = _authService.currentUser;
    if (user != null) {
      _updateFirestoreSingleArtist(user.email, artistId, artistData);
    }
  }

  // Method to update metadata if it was missing
  void updateArtistMetadata(String artistId, String name, String image) {
    if (_followedArtists.containsKey(artistId)) {
      final current = _followedArtists[artistId]!;
      if (current['name'] == 'Artist' || current['name'] == 'Unknown' || (current['image']?.isEmpty ?? true)) {
        final artistData = {
          'id': artistId,
          'name': name,
          'image': image,
        };
        _followedArtists[artistId] = artistData;
        _saveFollowedArtists();
        
        final user = _authService.currentUser;
        if (user != null) {
          _updateFirestoreSingleArtist(user.email, artistId, artistData);
        }
      }
    }
  }
}

