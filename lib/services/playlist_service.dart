// services/playlist_service.dart
import 'package:clone_mp/models/song_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class Playlist {
  final String id;
  final String name;
  final List<SongModel> songs;

  Playlist({required this.id, required this.name, this.songs = const []});

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var songList = json['songs'] as List;
    List<SongModel> songs = songList.map((i) => SongModel.fromJson(i)).toList();
    return Playlist(
      id: json['id'],
      name: json['name'],
      songs: songs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songs': songs.map((s) => s.toJson()).toList(),
    };
  }
}

class PlaylistService with ChangeNotifier {
  // --- LIKED SONGS ---
  List<SongModel> _likedSongs = [];
  List<SongModel> get likedSongs => _likedSongs;
  String? _currentUserEmail;

  // Load all user data from Firestore
  Future<void> loadUserData(String userEmail) async {
    _currentUserEmail = userEmail;
    await _loadLikedSongs();
    await _loadPlaylists();
    notifyListeners();
  }

  Future<void> _loadLikedSongs() async {
    if (_currentUserEmail == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserEmail)
        .collection('likedSongs')
        .get();
      _likedSongs = snapshot.docs
        .map((doc) => SongModel.fromJson(doc.data()))
        .toList();
    } catch (e) {
      debugPrint('Error loading liked songs: $e');
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
    if (_currentUserEmail == null) return; 

    if (isLiked(song)) {
      _likedSongs.removeWhere((s) => s.id == song.id);
      notifyListeners();

      // Remove from Firestore
      try {
        await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserEmail)
          .collection('likedSongs')
          .doc(song.id)
          .delete();
      } catch (e) {
        debugPrint('Error removing liked song: $e');
      }
    } else {
      _likedSongs.add(song);
      notifyListeners();

      // Add to Firestore
      try {
        await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserEmail)
          .collection('likedSongs')
          .doc(song.id)
          .set({
            ...song.toJson(),
            'likedAt': FieldValue.serverTimestamp(),
          });
      } catch (e) {
        debugPrint('Error saving liked song: $e');
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

  void createPlaylist(String name) {
    final newPlaylist = Playlist(id: _uuid.v4(), name: name);
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
