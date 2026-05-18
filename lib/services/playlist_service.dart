// services/playlist_service.dart
import 'package:clone_mp/models/song_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class Playlist {
  final String id;
  final String name;
  final List<SongModel> songs;
  final String? source;
  final List<Map<String, String>>? unmatchedSongs;
  final DateTime? createdAt;

  Playlist({
    required this.id,
    required this.name,
    this.songs = const [],
    this.source,
    this.unmatchedSongs,
    this.createdAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var songList = json['songs'] as List? ?? [];
    List<SongModel> songs = songList.map((i) => SongModel.fromJson(i)).toList();
    
    var unmatchedList = json['unmatchedSongs'] as List? ?? [];
    List<Map<String, String>> unmatched = unmatchedList.map((i) => Map<String, String>.from(i)).toList();

    return Playlist(
      id: json['id'],
      name: json['name'],
      songs: songs,
      source: json['source'],
      unmatchedSongs: unmatched,
      createdAt: json['createdAt'] != null ? (json['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songs': songs.map((s) => s.toJson()).toList(),
      'source': source,
      'unmatchedSongs': unmatchedSongs,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}

class PlaylistService with ChangeNotifier {
  // --- LIKED SONGS ---
  List<SongModel> _likedSongs = [];
  List<SongModel> get likedSongs => _likedSongs;
<<<<<<< HEAD
  String? _currentUserUid;
=======
  String? _currentUserId;
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a

  String? get _effectiveUserUid => _currentUserUid ?? FirebaseAuth.instance.currentUser?.uid;

  // Load all user data from Firestore
<<<<<<< HEAD
  Future<void> loadUserData(String userUid, String userEmail) async {
    _currentUserUid = userUid;
=======
  Future<void> loadUserData(String userId) async {
    _currentUserId = userId;
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
    await _loadLikedSongs();
    await _loadPlaylists();
    notifyListeners();
  }

  Future<void> _loadLikedSongs() async {
<<<<<<< HEAD
    final uid = _effectiveUserUid;
    if (uid == null) {
=======
<<<<<<< HEAD
    final email = _effectiveUserEmail;
    if (email == null) {
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
      debugPrint("🎵 PlaylistService: Cannot load liked songs - User not logged in.");
      return;
    }
=======
    if (_currentUserId == null) return;
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df
    try {
      debugPrint("🎵 PlaylistService: Loading liked songs for $uid...");
      final snapshot = await FirebaseFirestore.instance
        .collection('users')
<<<<<<< HEAD
        .doc(uid)
=======
<<<<<<< HEAD
        .doc(email)
=======
        .doc(_currentUserId)
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
        .collection('likedSongs')
        .orderBy('likedAt', descending: true)
        .get()
        .timeout(const Duration(seconds: 10));
      _likedSongs = snapshot.docs
        .map((doc) => SongModel.fromJson(doc.data()))
        .toList();
      debugPrint("🎵 PlaylistService: Loaded ${_likedSongs.length} liked songs.");
    } catch (e) {
      debugPrint('🎵 PlaylistService: Error loading liked songs: $e');
      _likedSongs = [];
    }
  }

  Future<void> _loadPlaylists() async {
<<<<<<< HEAD
    final uid = _effectiveUserUid;
    if (uid == null) return;
    try {
      final playlistSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
=======
    if (_currentUserId == null) return;
    try {
      final playlistSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
        .collection('playlists')
        .get()
        .timeout(const Duration(seconds: 10));
      _playlists = playlistSnapshot.docs
        .map((doc) => Playlist.fromJson(doc.data()))
        .toList();
    } catch (e) {
      debugPrint('Error loading playlists: $e');
      _playlists = [];
    }
  }

  // Clear data on logout
  void clearData() {
<<<<<<< HEAD
    _currentUserUid = null;
=======
    _currentUserId = null;
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
    _likedSongs = [];
    _playlists = [];
    notifyListeners();
  }

  bool isLiked(SongModel song) {
    return _likedSongs.any((s) => s.id == song.id);
  }

  Future<void> toggleLike(SongModel song) async {
<<<<<<< HEAD
    final uid = _effectiveUserUid;
    if (uid == null) {
=======
<<<<<<< HEAD
    final email = _effectiveUserEmail;
    if (email == null) {
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
      debugPrint("🎵 PlaylistService: Cannot toggle like - User session MISSING ❌");
      return;
    }
=======
    if (_currentUserId == null) return; 
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df

    if (isLiked(song)) {
      _likedSongs.removeWhere((s) => s.id == song.id);
      notifyListeners();

      // Remove from Firestore
      try {
        debugPrint("🎵 PlaylistService: REMOVING [${song.name}] from Firestore for $uid...");
        final snapshot = await FirebaseFirestore.instance
          .collection('users')
<<<<<<< HEAD
          .doc(uid)
=======
<<<<<<< HEAD
          .doc(email)
=======
          .doc(_currentUserId)
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
          .collection('likedSongs')
          .where('id', isEqualTo: song.id)
          .get();
        
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
        debugPrint("🎵 PlaylistService: Removed from Firestore SUCCESS ✅");
      } catch (e) {
        debugPrint('🎵 PlaylistService: Firestore REMOVE ERROR: $e ❌');
      }
    } else {
      _likedSongs.insert(0, song);
      notifyListeners();

      // Add to Firestore with a sortable ID
      try {
        debugPrint("🎵 PlaylistService: ADDING [${song.name}] to Firestore for $uid...");
        final int timestamp = DateTime.now().millisecondsSinceEpoch;
        final String docId = "${timestamp}_${song.id}";
        
        await FirebaseFirestore.instance
          .collection('users')
<<<<<<< HEAD
          .doc(uid)
=======
<<<<<<< HEAD
          .doc(email)
=======
          .doc(_currentUserId)
>>>>>>> c914e5c5b1c17aa2ececcad13b94a5a9d492e9df
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
          .collection('likedSongs')
          .doc(docId)
          .set({
            ...song.toJson(),
            'likedAt': FieldValue.serverTimestamp(),
            'sortId': timestamp,
          });
        debugPrint("🎵 PlaylistService: Firestore Sync: SUCCESS ✅ (Doc: $docId)");
      } catch (e) {
        debugPrint('🎵 PlaylistService: Firestore ADD ERROR: $e ❌');
      }
    }
  }

  // --- USER-CREATED PLAYLISTS ---
  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;
  final Uuid _uuid = const Uuid();

  Future<void> _savePlaylists() async {
<<<<<<< HEAD
    final uid = _effectiveUserUid;
    if (uid == null) return;
=======
    if (_currentUserId == null) return;
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Delete existing playlists first
      final existing = await FirebaseFirestore.instance
        .collection('users')
<<<<<<< HEAD
        .doc(uid)
=======
        .doc(_currentUserId)
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
        .collection('playlists')
        .get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      // Write current playlists
      for (final playlist in _playlists) {
        final ref = FirebaseFirestore.instance
          .collection('users')
<<<<<<< HEAD
          .doc(uid)
=======
          .doc(_currentUserId)
>>>>>>> 1671ff7f5cb9a1231988e20b30a32e284b6bec6a
          .collection('playlists')
          .doc(playlist.id);
        batch.set(ref, playlist.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  void createPlaylist(String name, {String? source, List<Map<String, String>>? unmatchedSongs, List<SongModel>? initialSongs}) {
    final newPlaylist = Playlist(
      id: _uuid.v4(),
      name: name,
      source: source,
      unmatchedSongs: unmatchedSongs,
      songs: initialSongs ?? [],
      createdAt: DateTime.now(),
    );
    _playlists.add(newPlaylist);
    notifyListeners();
    _savePlaylists();
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    _savePlaylists();
  }

  // Add multiple songs at once
  Future<void> addSongsToPlaylist(String playlistId, List<SongModel> newSongs) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex == -1) return;

    final oldPlaylist = _playlists[playlistIndex];

    // Filter duplicates
    final validNewSongs = newSongs.where((newS) {
      return !oldPlaylist.songs.any((oldS) => oldS.id == newS.id);
    }).toList();

    if (validNewSongs.isNotEmpty) {
      final newSongList = List<SongModel>.from(oldPlaylist.songs)
        ..addAll(validNewSongs);

      _playlists[playlistIndex] = Playlist(
        id: oldPlaylist.id,
        name: oldPlaylist.name,
        songs: newSongList,
      );
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final oldPlaylist = _playlists[playlistIndex];
      _playlists[playlistIndex] = Playlist(
        id: oldPlaylist.id,
        name: newName,
        songs: oldPlaylist.songs,
      );
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final oldPlaylist = _playlists[playlistIndex];
      final newSongList = List<SongModel>.from(oldPlaylist.songs)
        ..removeWhere((s) => s.id == songId);

      _playlists[playlistIndex] = Playlist(
        id: oldPlaylist.id,
        name: oldPlaylist.name,
        songs: newSongList,
      );
      notifyListeners();
      await _savePlaylists();
    }
  }
}
