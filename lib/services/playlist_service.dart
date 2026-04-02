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
  String? _currentUserEmail;

  String? get _effectiveUserEmail => _currentUserEmail ?? FirebaseAuth.instance.currentUser?.email;

  // Load all user data from Firestore
  Future<void> loadUserData(String userEmail) async {
    _currentUserEmail = userEmail;
    await _loadLikedSongs();
    await _loadPlaylists();
    notifyListeners();
  }

  Future<void> _loadLikedSongs() async {
    final email = _effectiveUserEmail;
    if (email == null) {
      debugPrint("🎵 PlaylistService: Cannot load liked songs - User not logged in.");
      return;
    }
    try {
      debugPrint("🎵 PlaylistService: Loading liked songs for $email...");
      final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('likedSongs')
        .orderBy('likedAt', descending: true)
        .get();
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
    if (_currentUserEmail == null) return;
    try {
      final playlistSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserEmail)
        .collection('playlists')
        .get();
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
    _currentUserEmail = null;
    _likedSongs = [];
    _playlists = [];
    notifyListeners();
  }

  bool isLiked(SongModel song) {
    return _likedSongs.any((s) => s.id == song.id);
  }

  Future<void> toggleLike(SongModel song) async {
    final email = _effectiveUserEmail;
    if (email == null) {
      debugPrint("🎵 PlaylistService: Cannot toggle like - User session MISSING ❌");
      return;
    }

    if (isLiked(song)) {
      _likedSongs.removeWhere((s) => s.id == song.id);
      notifyListeners();

      // Remove from Firestore
      try {
        debugPrint("🎵 PlaylistService: REMOVING [${song.name}] from Firestore for $email...");
        final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
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
        debugPrint("🎵 PlaylistService: ADDING [${song.name}] to Firestore for $email...");
        final int timestamp = DateTime.now().millisecondsSinceEpoch;
        final String docId = "${timestamp}_${song.id}";
        
        await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
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
    if (_currentUserEmail == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Delete existing playlists first
      final existing = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserEmail)
        .collection('playlists')
        .get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      // Write current playlists
      for (final playlist in _playlists) {
        final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserEmail)
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
